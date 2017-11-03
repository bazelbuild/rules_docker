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

load("//container:bundle.bzl", "container_bundle")

def _impl(ctx):
    config_str = ' '.join(['$(pwd)/' + c.short_path for c in ctx.files.configs])

    # image_name = "bazel/%s:%s" % (ctx.attr.image.label.package, ctx.attr.image.label.name)

    # Generate a shell script to execute structure_tests with the correct flags.
    ctx.actions.expand_template(
        template=ctx.file._structure_test_tpl,
        output=ctx.outputs.executable,
        substitutions={
          # call the image as an executable to load it in the daemon
          "%{load_statement}": ctx.executable.image.short_path,
          "%{configs}": config_str,
          "%{workspace_name}": ctx.workspace_name,
          "%{test_executable}": ctx.executable._structure_test.short_path,
          # "%{image}": image_name,
          "%{image}": ctx.attr.image
        },
        is_executable=True
    )

    return struct(runfiles=ctx.runfiles(files = [
            ctx.executable._structure_test,
            ctx.executable.image] +
            ctx.attr.image.files.to_list() +
            ctx.attr.image.data_runfiles.files.to_list() +
            ctx.files.configs,
        ),
    )

_container_test = rule(
    attrs = {
        "image": attr.label(
            executable = True,
            mandatory = True,
            cfg = "target",
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
        ),
        "_structure_test": attr.label(
            default = Label("@structure_test//:go_default_test"),
            cfg = "target",
            executable = True,
            allow_files = True,
        ),
        "_structure_test_tpl": attr.label(
            default = Label("//container:structure-test.sh.tpl"),
            allow_files = True,
            single_file = True,
        ),
    },
    executable = True,
    test = True,
    implementation = _impl,
)


def container_test(name, image, configs, driver=None, verbose=None):
    intermediate_image_name = "%s.intermediate" % image

    container_bundle(
        name = "intermediate_bundle",
        images = {
            intermediate_image_name: image,
        }
    )

    _container_test(
        name = name,
        image = intermediate_image_name,
        configs = configs,
        verbose = verbose,
        driver = driver,
    )
