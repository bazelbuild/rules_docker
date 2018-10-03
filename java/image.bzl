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

load(
    "//container:container.bzl",
    "container_pull",
    _container = "container",
    _repositories = "repositories",
)
load(
    "//lang:image.bzl",
    "dep_layer_impl",
    "layer_file_path",
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
    # Call the core "repositories" function to reduce boilerplate.
    # This is idempotent if folks call it themselves.
    _repositories()

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
        native.maven_jar(
            name = "javax_servlet_api",
            artifact = "javax.servlet:javax.servlet-api:3.0.1",
        )

DEFAULT_JAVA_BASE = select({
    "@io_bazel_rules_docker//:fastbuild": "@java_image_base//image",
    "@io_bazel_rules_docker//:debug": "@java_debug_image_base//image",
    "@io_bazel_rules_docker//:optimized": "@java_image_base//image",
    "//conditions:default": "@java_image_base//image",
})

DEFAULT_JETTY_BASE = select({
    "@io_bazel_rules_docker//:fastbuild": "@jetty_image_base//image",
    "@io_bazel_rules_docker//:debug": "@jetty_debug_image_base//image",
    "@io_bazel_rules_docker//:optimized": "@jetty_image_base//image",
    "//conditions:default": "@jetty_image_base//image",
})

def java_files(f):
    files = []
    if java_common.provider in f:
        java_provider = f[java_common.provider]
        files += list(java_provider.transitive_runtime_jars)
    if hasattr(f, "files"):  # a jar file
        files += list(f.files)
    return files

def java_files_with_data(f):
    files = java_files(f)
    if hasattr(f, "data_runfiles"):
        files += list(f.data_runfiles.files)
    return files

def _jar_dep_layer_impl(ctx):
    """Appends a layer for a single dependency's runfiles."""

    # Note the use of java_files (instead of java_files_with_data) here.
    # This causes the dep_layer to include only source files and none of
    # the data_runfiles. This is probably not ideal -- it would be better
    # to have the runfiles of the dependencies in the dep_layer, and only
    # the runfiles of the java_image in the top layer. Doing this without
    # also pulling in the JDK deps will requrie extending the dep_layer_impl
    # with functionality to exclude certain runfiles. Rather than making it
    # JDK specific, an option would be to add a `skipfiles = ctx.files._jdk`
    # type option here. The app layer would also need to be updated to
    # consider data flies include in the dep_layer as "available" so they
    # aren't duplicated in the top layer.
    return dep_layer_impl(ctx, runfiles = java_files_with_data)

jar_dep_layer = rule(
    attrs = dict(_container.image.attrs.items() + {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(mandatory = True),

        # Whether to lay out each dependency in a manner that is agnostic
        # of the binary in which it is participating.  This can increase
        # sharing of the dependency's layer across images, but requires a
        # symlink forest in the app layers.
        "agnostic_dep_layout": attr.bool(default = True),

        # Override the defaults.
        "directory": attr.string(default = "/app"),
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
        "legacy_run_behavior": attr.bool(default = False),
    }.items()),
    executable = True,
    outputs = _container.image.outputs,
    implementation = _jar_dep_layer_impl,
)

def _jar_app_layer_impl(ctx):
    """Appends the app layer with all remaining runfiles."""

    available = depset()
    for jar in ctx.attr.jar_layers:
        available += java_files(jar)  # layers don't include runfiles

    # We compute the set of unavailable stuff by walking deps
    # in the same way, adding in our binary and then subtracting
    # out what it available.
    unavailable = depset()
    for jar in ctx.attr.deps + ctx.attr.runtime_deps:
        unavailable += java_files_with_data(jar)

    unavailable += java_files_with_data(ctx.attr.binary)
    unavailable = [x for x in unavailable if x not in available]

    # Remove files that are provided by the JDK from the unavailable set,
    # as these will be provided by the Java image.
    jdk_files = depset(list(ctx.files._jdk))
    unavailable = [x for x in unavailable if x not in ctx.files._jdk]

    classpath = ":".join([
        layer_file_path(ctx, x)
        for x in available + unavailable
    ])

    # Classpaths can grow long and there is a limit on the length of a
    # command line, so mitigate this by always writing the classpath out
    # to a file instead.
    classpath_file = ctx.new_file(ctx.attr.name + ".classpath")
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
        "@" + classpath_path if ctx.attr._classpath_as_file else classpath,
    ] + jvm_flags + [ctx.attr.main_class] + args

    file_map = {
        layer_file_path(ctx, f): f
        for f in unavailable + [classpath_file]
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
    attrs = dict(_container.image.attrs.items() + {
        # The binary target for which we are synthesizing an image.
        "binary": attr.label(mandatory = True),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "jar_layers": attr.label_list(),
        # The rest of the dependencies.
        "deps": attr.label_list(),
        "runtime_deps": attr.label_list(),
        "jvm_flags": attr.string_list(),
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The main class to invoke on startup.
        "main_class": attr.string(mandatory = True),

        # Whether to lay out each dependency in a manner that is agnostic
        # of the binary in which it is participating.  This can increase
        # sharing of the dependency's layer across images, but requires a
        # symlink forest in the app layers.
        "agnostic_dep_layout": attr.bool(default = True),

        # Whether the classpath should be passed as a file.
        "_classpath_as_file": attr.bool(default = False),

        # Override the defaults.
        "directory": attr.string(default = "/app"),
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
        "workdir": attr.string(default = ""),
        "legacy_run_behavior": attr.bool(default = False),
        "data": attr.label_list(allow_files = True),
        "_jdk": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo],
        ),
    }.items()),
    executable = True,
    outputs = _container.image.outputs,
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
        **kwargs):
    """Builds a container image overlaying the java_binary.

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See java_binary.
  """
    binary_name = name + ".binary"

    native.java_binary(
        name = binary_name,
        main_class = main_class,
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
    )

def _war_dep_layer_impl(ctx):
    """Appends a layer for a single dependency's runfiles."""

    # TODO(mattmoor): Today we run the risk of filenames colliding when
    # they get flattened.  Instead of just flattening and using basename
    # we should use a file_map based scheme.
    return _container.image.implementation(
        ctx,
        files = java_files(ctx.attr.dep),
    )

_war_dep_layer = rule(
    attrs = dict(_container.image.attrs.items() + {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(mandatory = True),

        # Whether to lay out each dependency in a manner that is agnostic
        # of the binary in which it is participating.  This can increase
        # sharing of the dependency's layer across images, but requires a
        # symlink forest in the app layers.
        "agnostic_dep_layout": attr.bool(default = True),

        # Override the defaults.
        "directory": attr.string(default = "/jetty/webapps/ROOT/WEB-INF/lib"),
        # WE WANT PATHS FLATTENED
        # "data_path": attr.string(default = "."),
        "legacy_run_behavior": attr.bool(default = False),
    }.items()),
    executable = True,
    outputs = _container.image.outputs,
    implementation = _war_dep_layer_impl,
)

def _war_app_layer_impl(ctx):
    """Appends the app layer with all remaining runfiles."""

    available = depset()
    for jar in ctx.attr.jar_layers:
        available += java_files(jar)

    # This is based on rules_appengine's WAR rules.
    transitive_deps = depset()
    transitive_deps += java_files(ctx.attr.library)

    # TODO(mattmoor): Handle data files.

    # If we start putting libs in servlet-agnostic paths,
    # then consider adding symlinks here.
    files = [d for d in transitive_deps if d not in available]

    return _container.image.implementation(ctx, files = files)

_war_app_layer = rule(
    attrs = dict(_container.image.attrs.items() + {
        # The library target for which we are synthesizing an image.
        "library": attr.label(mandatory = True),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "jar_layers": attr.label_list(),
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        "entrypoint": attr.string_list(default = []),

        # Whether to lay out each dependency in a manner that is agnostic
        # of the binary in which it is participating.  This can increase
        # sharing of the dependency's layer across images, but requires a
        # symlink forest in the app layers.
        "agnostic_dep_layout": attr.bool(default = True),

        # Override the defaults.
        "directory": attr.string(default = "/jetty/webapps/ROOT/WEB-INF/lib"),
        # WE WANT PATHS FLATTENED
        # "data_path": attr.string(default = "."),
        "legacy_run_behavior": attr.bool(default = False),
    }.items()),
    executable = True,
    outputs = _container.image.outputs,
    implementation = _war_app_layer_impl,
)

def war_image(name, base = None, deps = [], layers = [], **kwargs):
    """Builds a container image overlaying the java_library as an exploded WAR.

  TODO(mattmoor): For `bazel run` of this to be useful, we need to be able
  to ctrl-C it and have the container actually terminate.  More information:
  https://github.com/bazelbuild/bazel/issues/3519

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See java_library.
  """
    library_name = name + ".library"

    native.java_library(name = library_name, deps = deps + layers, **kwargs)

    base = base or DEFAULT_JETTY_BASE
    for index, dep in enumerate(layers):
        this_name = "%s.%d" % (name, index)
        _war_dep_layer(name = this_name, base = base, dep = dep)
        base = this_name

    visibility = kwargs.get("visibility", None)
    tags = kwargs.get("tags", None)
    _war_app_layer(
        name = name,
        base = base,
        library = library_name,
        jar_layers = layers,
        visibility = visibility,
        tags = tags,
    )
