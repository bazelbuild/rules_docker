# Copyright 2020 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import argparse
import hashlib
import json
import shlex
import shutil
import subprocess
import sys
import tarfile
from contextlib import closing, contextmanager
from os.path import basename, dirname
from pathlib import Path
from time import sleep
from uuid import uuid4

COPY_BLOCK_SIZE = 1024 * 1024 * 4


class ContainerFailed(Exception):
    pass


class DockerError(Exception):
    pass


class BoundedInputFile:
    def __init__(self, fh, bound):
        self._fh = fh
        self._bound = bound

    def read(self, count):
        buf = self._fh.read(min(count, self._bound))
        self._bound -= len(buf)
        return buf


class SHA256File:
    def __init__(self, fh):
        self._fh = fh
        self._hasher = hashlib.sha256()

    def __enter__(self):
        self._fh.__enter__()
        return self

    def __exit__(self, *args):
        return self._fh.__exit__(*args)

    def write(self, buf):
        self._hasher.update(buf)
        return self._fh.write(buf)

    def hexdigest(self):
        return self._hasher.hexdigest()


def roundup_block(size):
    blocks = (size + 511) >> 9
    return blocks << 9


class NullFile:
    @staticmethod
    def write(buf):
        return len(buf)


def should_skip(ti):
    # Docker outputs the files in this format, so we don't need to normalize
    # e.g. we don't need to remove leading ./
    if ti.name in ("tmp", "var/tmp"):
        # Don't take /tmp or anything left in /tmp
        # If we do, we can end up overwriting the 0o1777 mode for /tmp,
        # which breaks things down the line
        return True

    if ti.name.startswith(("tmp/", "var/tmp/")):
        return True

    return False


def get_layer_from_bundle(fh, label):
    target = None
    while True:
        buf = fh.read(tarfile.BLOCKSIZE)
        try:
            ti = tarfile.TarInfo.frombuf(
                buf, tarfile.ENCODING, "surrogateescape"
            )
        except tarfile.EOFHeaderError:
            break

        len_to_read = roundup_block(ti.size)
        if ti.name == target:
            return BoundedInputFile(fh, ti.size)

        if basename(ti.name) == "json":
            buf = fh.read(ti.size)
            len_to_read -= ti.size

            if has_label(buf, label):
                target = dirname(ti.name) + "/layer.tar"

        while len_to_read:
            buf = fh.read(min(COPY_BLOCK_SIZE, len_to_read))
            len_to_read -= len(buf)


def has_label(data, key):
    decoded = json.loads(data)
    try:
        config = decoded["config"]
    except KeyError:
        return False

    labels = config["Labels"]
    return key in labels


def reset_mtime(mtime, in_fh, out_fh):
    while True:
        buf = in_fh.read(tarfile.BLOCKSIZE)
        try:
            ti = tarfile.TarInfo.frombuf(
                buf, tarfile.ENCODING, "surrogateescape"
            )
        except tarfile.EOFHeaderError:
            break

        ti.mtime = min(ti.mtime, mtime)
        destination = NullFile if should_skip(ti) else out_fh

        len_to_read = roundup_block(ti.size)
        destination.write(ti.tobuf())
        tarfile.copyfileobj(in_fh, destination, len_to_read)

    out_fh.write(b"\0" * (tarfile.BLOCKSIZE * 2))


class Docker:
    def __init__(self, fixed_args):
        self._fixed_args = tuple(fixed_args)

    def _act(self, func, args, **kwargs):
        args = self._fixed_args + args
        return func(args, **kwargs)

    def run(self, *args, check=True, **kwargs):
        return self._act(subprocess.run, args, check=check, **kwargs)

    def check_output(self, *args, **kwargs):
        return self._act(subprocess.check_output, args, **kwargs)

    def popen(self, *args, **kwargs):
        return self._act(subprocess.Popen, args, **kwargs)

    @contextmanager
    def image(self, *args):
        image_id = self.check_output("commit", *args).rstrip()
        try:
            yield image_id
        finally:
            self.run("rmi", image_id, stdout=subprocess.DEVNULL)

    @contextmanager
    def container(self, *args):
        container_id = self.check_output("create", *args).rstrip().decode()
        try:
            yield container_id
        finally:
            self.run("rm", container_id, stdout=subprocess.DEVNULL)


def extract_file(docker, container_id: str, extract_path, output_path) -> None:
    """Extracts the last layer from a docker image from an image tarball

  Args:
    extract_path: str path to copy from the container
    output_path: str path to write to

  """
    label = str(uuid4())
    docker.run("cp", f"{container_id}:{extract_path}", output_path)


def extract_last_layer(
    docker, container_id, *, output_path, output_diffid_path, mtime=0
):
    """Extracts the last layer from a docker image from an image tarball

  Args:
    layer_path: str path for the output layer
    diffid_path: str path for the layer diff ID

  Returns:
    str the diff ID of the layer

  """
    label = str(uuid4())
    with docker.image("--change", f"LABEL {label}=", container_id) as image_id:
        docker_save = docker.popen("save", image_id, stdout=subprocess.PIPE)
        with closing(docker_save.stdout) as image_tar:
            last_layer = get_layer_from_bundle(image_tar, label)

            with SHA256File(open(output_path, "wb")) as out_fh:
                if mtime is not None:
                    reset_mtime(mtime, last_layer, out_fh)
                else:
                    tarfile.copyfileobj(last_layer, out_fh)

        ret = docker_save.wait()
        if ret not in (
            -13,  # Linux SIGPIPE
            0,
            255,  # MacOS SIGPIPE-equivalent
        ):
            raise DockerError("docker save returned unexpected code", ret)

    with open(output_diffid_path, "w") as f:
        f.write(out_fh.hexdigest())


def run(
    output,
    *,
    docker,
    image_id_file,
    image_config,
    executable,
    docker_run_flags,
    command,
    **kwargs,
):
    image_id = Path(image_id_file).read_text().rstrip()
    architecture = image_config["architecture"]
    subprocess.run(executable, check=True, stdout=subprocess.DEVNULL)
    args = shlex.split(docker_run_flags)
    args.append("--entrypoint=/bin/sh")
    args.append("--platform=linux/{}".format(architecture))
    args.append(image_id)
    args.append("-c")
    args.append("set -e\n" + "\n".join(command))

    with docker.container(*args) as container_id:
        try:
            ret = docker.run(
                "start", "-a", container_id, stdout=output, stderr=output
            )
        except subprocess.CalledProcessError as e:
            raise ContainerFailed

        if "output_diffid_path" in kwargs:
            extract_last_layer(
                docker, container_id, **kwargs,
            )
        elif "extract_path" in kwargs:
            extract_file(docker, container_id, **kwargs)
        else:
            raise Exception("Nothing to persist!")


def get_docker(args):
    cmd = [args.pop("docker")]
    cmd.extend(shlex.split(args.pop("docker-flags")))
    return Docker(cmd)


def read_json(filename):
    with open(filename, "rb") as fh:
        return json.load(fh)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--docker-run-flags")
    parser.add_argument("--mtime", type=int)
    parser.add_argument("--logfile", required=True)
    parser.add_argument("--image-config", required=True, type=read_json)
    parser.add_argument("--output-diffid-path")
    parser.add_argument("--extract-path")
    parser.add_argument("executable")
    parser.add_argument("image_id_file")
    parser.add_argument("docker")
    parser.add_argument("docker-flags")
    parser.add_argument("output_path")
    parser.add_argument('command', nargs=argparse.REMAINDER)

    args = {
        k: v for k, v in vars(parser.parse_args()).items() if v is not None
    }
    args["docker"] = get_docker(args)
    logfile = args.pop("logfile")

    try:
        with open(logfile, "w") as log_fh:
            run(log_fh, **args)
    except ContainerFailed as e:
        pass
    else:
        return 0

    with open(logfile, "rb") as log_fh:
        shutil.copyfileobj(log_fh, sys.stderr.buffer)

    return 1


if __name__ == '__main__':
    raise SystemExit(main())
