# Copyright 2017 The Bazel Authors. All rights reserved.
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
"""A wrapper around container structure tests for Bazel.

This rule feeds a built image and a set of config files
to the container structure test framework."
"""

load(
    "//container:bundle.bzl",
    "container_bundle",
)

def _impl(ctx):
    config_str = " ".join(["--config $(pwd)/" + c.short_path for c in ctx.files.configs])

    if ctx.attr.driver == "tar":
        # no need to load if we're using raw tar
        load_statement = ""
        image_name = "$(pwd)/" + ctx.file.image_tar.short_path

    else:
        # Since we're always bundling/renaming the image in the macro, this is valid.
        load_statement = "docker load -i %s" % ctx.file.image_tar.short_path
        image_name = ctx.attr.image_name

    quiet_str = "--quiet"
    if ctx.attr.verbose:
        quiet_str = ""

    # Generate a shell script to execute structure_tests with the correct flags.
    ctx.actions.expand_template(
        template = ctx.file._structure_test_tpl,
        output = ctx.outputs.executable,
        substitutions = {
            "%{load_statement}": load_statement,
            "%{configs}": config_str,
            "%{test_executable}": ctx.executable._structure_test.short_path,
            "%{image}": image_name,
            "%{driver}": ctx.attr.driver,
            "%{quiet}": quiet_str,
        },
        is_executable = True,
    )

    return struct(
        runfiles = ctx.runfiles(
            files = [
                        ctx.executable._structure_test,
                        ctx.executable.image_tar,
                        ctx.file.image_tar,
                    ] +
                    ctx.attr.image_tar.files.to_list() +
                    ctx.attr.image_tar.data_runfiles.files.to_list() +
                    ctx.files.configs,
        ),
    )

_container_test = rule(
    attrs = {
        "image_tar": attr.label(
            executable = True,
            allow_files = True,
            mandatory = True,
            single_file = True,
            cfg = "target",
        ),
        "image_name": attr.string(
            mandatory = True,
        ),
        "configs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "verbose": attr.bool(
            default = False,
            mandatory = False,
        ),
        "driver": attr.string(
            default = "docker",
            doc = "Driver to use when running structure tests",
            mandatory = False,
            values = [
                "docker",
                "tar",
            ],
        ),
        "_structure_test": attr.label(
            default = Label("//contrib:structure_test_executable"),
            cfg = "target",
            executable = True,
            allow_files = True,
        ),
        "_structure_test_tpl": attr.label(
            default = Label("//contrib:structure-test.sh.tpl"),
            allow_files = True,
            single_file = True,
        ),
    },
    executable = True,
    test = True,
    implementation = _impl,
)

def container_test(name, image, configs, driver = None, verbose = None, **kwargs):
    """A macro to predictably rename the image under test before threading
    it to the container test rule."""

    # Remove commonly encountered characters that Docker will choke on.
    # Include the package name in the new image tag to avoid conflicts on naming
    # when running multiple container_test on images with the same target name
    # from different packages.
    sanitized_name = (native.package_name() + image).replace(":", "").replace("@", "").replace("/", "")
    intermediate_image_name = "%s:intermediate" % sanitized_name
    image_tar_name = "intermediate_bundle_%s" % name

    # Give the image a predictable name when loaded
    container_bundle(
        name = image_tar_name,
        images = {
            intermediate_image_name: image,
        },
    )
    _container_test(
        name = name,
        image_name = intermediate_image_name,
        image_tar = image_tar_name + ".tar",
        configs = configs,
        verbose = verbose,
        driver = driver,
        **kwargs
    )
