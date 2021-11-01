# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""A rule for creating a Java container image.

The signature of java_image is compatible with java_binary.

The signature of war_image is compatible with java_library.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_tools//tools/build_defs/repo:jvm.bzl", "jvm_maven_import_external")
load(
    "//container:container.bzl",
    "container_pull",
    _container = "container",
)
load(
    "//lang:image.bzl",
    "layer_file_path",
    lang_image = "image",
)
load(
    "//repositories:go_repositories.bzl",
    _go_deps = "go_deps",
)

# Load the resolved digests.
load(
    ":java.bzl",
    _JAVA_DIGESTS = "DIGESTS",
)
load(
    ":jetty.bzl",
    _JETTY_DIGESTS = "DIGESTS",
)

def repositories():
    """Import the dependencies of the java_image rule.

    Call the core "go_deps" function to reduce boilerplate. This is
    idempotent if folks call it themselves.
    """
    _go_deps()

    excludes = native.existing_rules().keys()
    if "java_image_base" not in excludes:
        container_pull(
            name = "java_image_base",
            registry = "gcr.io",
            repository = "distroless/java",
            digest = _JAVA_DIGESTS["latest"],
        )
    if "java_debug_image_base" not in excludes:
        container_pull(
            name = "java_debug_image_base",
            registry = "gcr.io",
            repository = "distroless/java",
            digest = _JAVA_DIGESTS["debug"],
        )
    if "jetty_image_base" not in excludes:
        container_pull(
            name = "jetty_image_base",
            registry = "gcr.io",
            repository = "distroless/java/jetty",
            digest = _JETTY_DIGESTS["latest"],
        )
    if "jetty_debug_image_base" not in excludes:
        container_pull(
            name = "jetty_debug_image_base",
            registry = "gcr.io",
            repository = "distroless/java/jetty",
            digest = _JETTY_DIGESTS["debug"],
        )
    if "javax_servlet_api" not in excludes:
        jvm_maven_import_external(
            name = "javax_servlet_api",
            artifact = "javax.servlet:javax.servlet-api:3.0.1",
            artifact_sha256 = "377d8bde87ac6bc7f83f27df8e02456d5870bb78c832dac656ceacc28b016e56",
            server_urls = ["https://repo1.maven.org/maven2"],
            licenses = ["notice"],  # Apache 2.0
        )

DEFAULT_JAVA_BASE = select({
    "@io_bazel_rules_docker//:debug": "@java_debug_image_base//image",
    "@io_bazel_rules_docker//:fastbuild": "@java_image_base//image",
    "@io_bazel_rules_docker//:optimized": "@java_image_base//image",
    "//conditions:default": "@java_image_base//image",
})

DEFAULT_JETTY_BASE = select({
    "@io_bazel_rules_docker//:debug": "@jetty_debug_image_base//image",
    "@io_bazel_rules_docker//:fastbuild": "@jetty_image_base//image",
    "@io_bazel_rules_docker//:optimized": "@jetty_image_base//image",
    "//conditions:default": "@jetty_image_base//image",
})

def java_files(f):
    """Filter out the list of java source files from the given list of runfiles.

    Args:
        f: Runfiles for a java_image rule.

    Returns:
        Depset of java source files.
    """
    files = []

    if JavaInfo in f:
        java_provider = f[JavaInfo]
        files.append(java_provider.transitive_runtime_jars)

    f_files = f[DefaultInfo].files
    if f_files != None:
        files.append(f_files)

    return depset(transitive = files)

def java_files_with_data(f):
    """Filter out the list of java source and data files from the given list of runfiles.

    Args:
       f: Runfiles for a java_image rule.

    Returns:
       Depset of java source and data files.
    """
    files = java_files(f)
    data_runfiles = f[DefaultInfo].data_runfiles
    if data_runfiles != None:
        files = depset(transitive = [files, data_runfiles.files])
    return files

def _jar_dep_layer_impl(ctx):
    """Appends a layer for a single dependency's runfiles."""

    # Note the use of java_files (instead of java_files_with_data) here.
    # This causes the dep_layer to include only source files and none of
    # the data_runfiles. This is probably not ideal -- it would be better
    # to have the runfiles of the dependencies in the dep_layer, and only
    # the runfiles of the java_image in the top layer. Doing this without
    # also pulling in the JDK deps will requrie extending the app_layer_impl
    # with functionality to exclude certain runfiles. Rather than making it
    # JDK specific, an option would be to add a `skipfiles = ctx.files._jdk`
    # type option here. The app layer would also need to be updated to
    # consider data flies include in the dep_layer as "available" so they
    # aren't duplicated in the top layer.
    return lang_image.implementation(ctx, runfiles = java_files_with_data)

jar_dep_layer = rule(
    attrs = lang_image.attrs,
    executable = True,
    outputs = lang_image.outputs,
    toolchains = lang_image.toolchains,
    implementation = _jar_dep_layer_impl,
)

def _jar_app_layer_impl(ctx):
    """Appends the app layer with all remaining runfiles."""

    # layers don't include runfiles
    available = depset(transitive = [java_files(jar) for jar in ctx.attr.jar_layers])

    # We compute the set of unavailable stuff by walking deps
    # in the same way, adding in our binary and then subtracting
    # out what is in available.
    unavailable = depset(transitive = [java_files_with_data(jar) for jar in ctx.attr.deps + ctx.attr.runtime_deps])
    unavailable = depset(transitive = [unavailable, java_files_with_data(ctx.attr.binary)])
    unavailable = depset([x for x in unavailable.to_list() if x not in available.to_list()])

    # Remove files that are provided by the JDK from the unavailable set,
    # as these will be provided by the Java image.
    unavailable = depset([x for x in unavailable.to_list() if x not in ctx.files._jdk])

    classpath = ":".join([layer_file_path(ctx, x) for x in depset(transitive = [available, unavailable]).to_list()])

    # Classpaths can grow long and there is a limit on the length of a
    # command line, so mitigate this by always writing the classpath out
    # to a file instead.
    classpath_file = ctx.actions.declare_file(ctx.attr.name + ".classpath")
    ctx.actions.write(classpath_file, classpath)

    binary_path = layer_file_path(ctx, ctx.files.binary[0])
    classpath_path = layer_file_path(ctx, classpath_file)

    # args and jvm flags of the form $(location :some_target) are expanded to the path of the underlying file
    args = [ctx.expand_location(arg, ctx.attr.data) for arg in ctx.attr.args]
    jvm_flags = [ctx.expand_location(flag, ctx.attr.data) for flag in ctx.attr.jvm_flags]

    entrypoint = [
        "/usr/bin/java",
        "-cp",
        # Support optionally passing the classpath as a file.
        "@" + classpath_path if ctx.attr.classpath_as_file else classpath,
    ] + jvm_flags + ([ctx.attr.main_class] + args if ctx.attr.main_class != "" else [])

    file_map = {
        layer_file_path(ctx, f): f
        for f in depset([classpath_file], transitive = [unavailable]).to_list()
    }

    return _container.image.implementation(
        ctx,
        # We use all absolute paths.
        directory = "/",
        env = {
            "JAVA_RUNFILES": "/app",
        },
        file_map = file_map,
        entrypoint = entrypoint,
    )

jar_app_layer = rule(
    attrs = dicts.add(_container.image.attrs, {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The binary target for which we are synthesizing an image.
        "binary": attr.label(mandatory = True),
        "data": attr.label_list(allow_files = True),
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),

        # The rest of the dependencies.
        "deps": attr.label_list(),
        # Override the defaults.
        "directory": attr.string(default = "/app"),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "jar_layers": attr.label_list(),
        "jvm_flags": attr.string_list(),
        "legacy_run_behavior": attr.bool(default = False),
        # The main class to invoke on startup.
        "main_class": attr.string(mandatory = False),
        "runtime_deps": attr.label_list(),
        "workdir": attr.string(default = ""),

        # Whether the classpath should be passed as a file.
        "classpath_as_file": attr.bool(default = False),
        "_jdk": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo],
        ),
    }),
    executable = True,
    outputs = _container.image.outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _jar_app_layer_impl,
)

def java_image(
        name,
        base = None,
        main_class = None,
        deps = [],
        runtime_deps = [],
        layers = [],
        jvm_flags = [],
        classpath_as_file = None,
        **kwargs):
    """Builds a container image overlaying the java_binary.

  Args:
    name: Name of the image target.
    base: Base image to use for the java image.
    deps: Dependencies of the java image rule.
    runtime_deps: Runtime dependencies of the java image.
    jvm_flags: Flags to pass to the JVM when running the java image.
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    main_class: This parameter is optional. If provided it will be used in the
                compilation of any additional sources, and as part of the
                construction of the container entrypoint. If not provided, the
                name parameter is used as the main_class when compiling any
                additional sources, and the main_class is not included in the
                construction of the container entrypoint. Omitting main_class
                allows the user to specify additional arguments to the JVM at
                runtime.
    **kwargs: See java_binary.
  """
    binary_name = name + ".binary"
    native.java_binary(
        name = binary_name,
        # Calling java_binary with main_class = None will work if the package
        # name contains java or javatest. In this case, the main_class is
        # guessed by the java_binary implementation. To avoid assumptions about
        # package locations, if the main_class is None we use the value of
        # the name parameter as main_class to allow the build to proceed.
        main_class = main_class if main_class != None else binary_name,
        # If the rule is turning a JAR built with java_library into
        # a binary, then it will appear in runtime_deps.  We are
        # not allowed to pass deps (even []) if there is no srcs
        # kwarg.
        deps = (deps + layers) or None,
        runtime_deps = runtime_deps,
        jvm_flags = jvm_flags,
        **kwargs
    )

    tags = kwargs.get("tags", None)
    base = base or DEFAULT_JAVA_BASE
    for index, dep in enumerate(layers):
        this_name = "%s.%d" % (name, index)
        jar_dep_layer(name = this_name, base = base, dep = dep, tags = tags)
        base = this_name

    visibility = kwargs.get("visibility", None)
    jar_app_layer(
        name = name,
        base = base,
        binary = binary_name,
        main_class = main_class,
        jvm_flags = jvm_flags,
        deps = deps,
        runtime_deps = runtime_deps,
        jar_layers = layers,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
        data = kwargs.get("data"),
        testonly = kwargs.get("testonly"),
        classpath_as_file = classpath_as_file,
    )

def _war_dep_layer_impl(ctx):
    """Appends a layer for a single dependency's runfiles."""

    # TODO(mattmoor): Today we run the risk of filenames colliding when
    # they get flattened.  Instead of just flattening and using basename
    # we should use a file_map based scheme.
    return _container.image.implementation(
        ctx,
        files = java_files(ctx.attr.dep).to_list(),
    )

_war_dep_layer = rule(
    attrs = dicts.add(_container.image.attrs, {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),

        # The binary target for which we are synthesizing an image.
        "binary": attr.label(mandatory = False),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(mandatory = True),

        # Override the defaults.
        "directory": attr.string(default = "/jetty/webapps/ROOT/WEB-INF/lib"),
        # WE WANT PATHS FLATTENED
        # "data_path": attr.string(default = "."),
        "legacy_run_behavior": attr.bool(default = False),
    }),
    executable = True,
    outputs = _container.image.outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _war_dep_layer_impl,
)

def _war_app_layer_impl(ctx):
    """Appends the app layer with all remaining runfiles."""

    available = depset(transitive = [java_files(jar) for jar in ctx.attr.jar_layers])

    # This is based on rules_appengine's WAR rules.
    transitive_deps = java_files(ctx.attr.library)
    # TODO(mattmoor): Handle data files.

    # If we start putting libs in servlet-agnostic paths,
    # then consider adding symlinks here.
    files = [d for d in transitive_deps.to_list() if d not in available.to_list()]

    return _container.image.implementation(ctx, files = files)

_war_app_layer = rule(
    attrs = dicts.add(_container.image.attrs, {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),

        # Override the defaults.
        "directory": attr.string(default = "/jetty/webapps/ROOT/WEB-INF/lib"),
        "entrypoint": attr.string_list(default = []),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "jar_layers": attr.label_list(),
        # WE WANT PATHS FLATTENED
        # "data_path": attr.string(default = "."),
        "legacy_run_behavior": attr.bool(default = False),
        # The library target for which we are synthesizing an image.
        "library": attr.label(mandatory = True),
    }),
    executable = True,
    outputs = _container.image.outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _war_app_layer_impl,
)

def war_image(name, base = None, deps = [], layers = [], **kwargs):
    """Builds a container image overlaying the java_library as an exploded WAR.

  TODO(mattmoor): For `bazel run` of this to be useful, we need to be able
  to ctrl-C it and have the container actually terminate.  More information:
  https://github.com/bazelbuild/bazel/issues/3519

  Args:
    name: Name of the war_image target.
    base: Base image to use for the war image.
    deps: Dependencies of the way image target.
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See java_library.
  """
    library_name = name + ".library"

    native.java_library(name = library_name, deps = deps + layers, **kwargs)

    base = base or DEFAULT_JETTY_BASE
    tags = kwargs.get("tags", None)
    for index, dep in enumerate(layers):
        this_name = "%s.%d" % (name, index)
        _war_dep_layer(name = this_name, base = base, dep = dep, tags = tags)
        base = this_name

    visibility = kwargs.get("visibility", None)
    _war_app_layer(
        name = name,
        base = base,
        library = library_name,
        jar_layers = layers,
        visibility = visibility,
        tags = tags,
    )
