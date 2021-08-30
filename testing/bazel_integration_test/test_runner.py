from pathlib import Path
import json
import os
import platform
import re
import shutil
from subprocess import Popen
import sys
import tempfile

from rules_python.python.runfiles import runfiles
r = runfiles.Create()

def modify_WORKSPACE(wksp, distro_path):
    """Update the WORKSPACE file in the example to point to our locally-built tar.gz
    This allows users to clone rules_docker, cd into the examples/dir, and run the example directly,
    while our integration tests use the locally-built copy.

    Args:
        wksp: filesystem absolute path of the bazel WORKSPACE file under test
        distro_path: runfiles path of the distro .tar.gz
    """
    with open(wksp, 'r') as wksp_file:
        content = wksp_file.read()
    # Replace the url for rules_python with our locally built one
    content = re.sub(
        r'url = "https://github.com/bazelbuild/rules_docker/releases/download/[^"]+"',
        'url = "file://%s"' % r.Rlocation(distro_path),
        content)
    content = re.sub(r'sha256 = "', '#\1', content)
    with open(wksp, 'w') as wksp_file:
        wksp_file.write(content)

def main(conf_file):
    with open(conf_file) as j:
        config = json.load(j)

    isWindows = platform.system() == 'Windows'
    bazelBinary = r.Rlocation(os.path.join(config['bazelBinaryWorkspace'], 'bazel.exe' if isWindows else 'bazel'))
    
    workspacePath = config['workspaceRoot']
    # Canonicalize bazel external/some_repo/foo
    if workspacePath.startswith('external/'):
        workspacePath = '..' + workspacePath[len('external'):]

    with tempfile.TemporaryDirectory(dir = os.environ['TEST_TMPDIR']) as tmpdir:
        workdir = os.path.join(tmpdir, "wksp")
        print("copying workspace under test %s to %s" % (workspacePath, workdir))
        shutil.copytree(workspacePath, workdir)

        modify_WORKSPACE(os.path.join(workdir, 'WORKSPACE'), config['distro'])

        for command in config['bazelCommands']:
            bazel_args = command.split(' ')
            try:
                doubleHyphenPos = bazel_args.index('--')
                print("patch that in ", doubleHyphenPos)
            except ValueError:
                pass


            # Bazel's wrapper script needs this or you get 
            # 2020/07/13 21:58:11 could not get the user's cache directory: $HOME is not defined
            os.environ['HOME'] = str(Path.home())

            bazel_args.insert(0, bazelBinary)
            bazel_process = Popen(bazel_args, cwd = workdir)
            bazel_process.wait()
            if bazel_process.returncode != 0:
                # Test failure in Bazel is exit 3
                # https://github.com/bazelbuild/bazel/blob/486206012a664ecb20bdb196a681efc9a9825049/src/main/java/com/google/devtools/build/lib/util/ExitCode.java#L44
                sys.exit(3)

if __name__ == '__main__':
  main(sys.argv[1])
