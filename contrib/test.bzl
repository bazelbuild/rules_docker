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
    if len([x for x in [ctx.attr.image, ctx.file.image_tar, ctx.file.image_config] if x]) != 1:
        fail("Exactly one of 'image', 'image_tar', 'image_config' must be specified")

    args = ["test", "--driver", ctx.attr.driver]

    if ctx.file.image_tar:
        # no need to load if we're using raw tar
        load_statement = ""
        args += ["--image", ctx.file.image_tar.short_path]
        runfiles = ctx.runfiles(
            files = [ctx.executable._structure_test, ctx.file.image_tar] + ctx.files.configs,
        )
    elif ctx.file.image_config:
        load_statement = ""
        args += ["--metadata", ctx.file.image_config.short_path, "--force", "True"]
        runfiles = ctx.runfiles(
            files = [ctx.executable._structure_test, ctx.file.image_config] + ctx.files.configs,
        )
    else:
        load_statement = "%s --norun" % ctx.executable.image.short_path
        args += ["--image", ctx.attr.loaded_name]
        runfiles = ctx.runfiles(
            files = [ctx.executable._structure_test, ctx.executable.image] + ctx.files.configs,
            transitive_files = ctx.attr.image[DefaultInfo].files,
        ).merge(ctx.attr.image[DefaultInfo].data_runfiles)

    if ctx.attr.verbose:
        args += ["--verbosity", "debug"]

    for c in ctx.files.configs:
        args += ["--config", c.short_path]

    # Generate a shell script to execute structure_tests with the correct flags.
    ctx.actions.expand_template(
        template = ctx.file._structure_test_tpl,
        output = ctx.outputs.executable,
        substitutions = {
            "%{args}": " ".join(args),
            "%{load_statement}": load_statement,
            "%{test_executable}": ctx.executable._structure_test.short_path,
        },
        is_executable = True,
    )

    return [DefaultInfo(runfiles = runfiles)]

_container_test = rule(
    attrs = {
        "configs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "driver": attr.string(
            default = "docker",
            doc = "Driver to use when running structure tests. Valid values are docker, host and tar",
            mandatory = False,
            values = [
                "docker",
                "host",
                "tar",
            ],
        ),
        "image": attr.label(
            doc = "When using the docker driver, label of the incremental loader",
            executable = True,
            cfg = "target",
        ),
        "image_config": attr.label(
            doc = "When using the host driver, label of the container metadata file",
            allow_single_file = [".json", ".yaml", ".yml"],
        ),
        "image_tar": attr.label(
            doc = "When using the tar driver, label of the container image tarball",
            allow_single_file = [".tar"],
        ),
        "loaded_name": attr.string(
            doc = "When using the docker driver, the name:tag of the image when loaded into the docker daemon",
        ),
        "verbose": attr.bool(
            default = False,
            mandatory = False,
        ),
        "_structure_test": attr.label(
            default = Label("//contrib:structure_test_executable"),
            cfg = "exec",
            executable = True,
            allow_files = True,
        ),
        "_structure_test_tpl": attr.label(
            default = Label("//contrib:structure-test.sh.tpl"),
            allow_single_file = True,
        ),
    },
    executable = True,
    test = True,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _impl,
)

def container_test(name, image, configs, driver = None, verbose = None, **kwargs):
    """Renames the image under test before threading it to the container test rule.

    See also https://github.com/GoogleContainerTools/container-structure-test

    Args:
      name: The name of this container_test rule
      image: The image to use for testing
      configs: List of YAML or JSON config files with tests
      driver: Driver to use when running structure tests
      verbose: Turns on/off verbose logging. Default False.
      **kwargs: Attrs to pass through
    """

    image_loader = None
    image_tar = None
    image_config = None
    loaded_name = None

    if driver == "tar":
        image_tar = image + ".tar"
    elif driver == "host":
        image_config = image + ".json"
    else:
        if image.endswith(".tar"):
            fail("It is not supported to directly use a tarball as the input " +
                 "image when 'driver' is 'docker'. Please use " +
                 "'container_load' repository rule to load the image tarball " +
                 "into rules_docker's intermediate format first and then use " +
                 "the target produced in the 'container_test' target.")

        # Give the image a predictable name when loaded
        image_loader = "%s.image" % name

        # Remove commonly encountered characters that Docker will choke on.
        # Include the package name in the new image tag to avoid conflicts on naming
        # when running multiple container_test on images with the same target name
        # from different packages.
        sanitized_name = (native.package_name() + image).replace(":", "").replace("@", "").replace("/", "")
        loaded_name = "%s:intermediate" % sanitized_name
        restricted_to = kwargs.get("restricted_to", None)
        compatible_with = kwargs.get("compatible_with", None)
        tags = kwargs.get("tags", [])

        container_bundle(
            name = image_loader,
            images = {
                loaded_name: image,
            },
            restricted_to = restricted_to,
            compatible_with = compatible_with,
            tags = tags,
        )

    _container_test(
        name = name,
        loaded_name = loaded_name,
        image = image_loader,
        image_tar = image_tar,
        image_config = image_config,
        configs = configs,
        verbose = verbose,
        driver = driver,
        **kwargs
    )
