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
"""A rule for creating a Java Docker image.

The signature of java_image is compatible with java_binary.

The signature of war_image is compatible with java_library.
"""

load("//docker:pull.bzl", "docker_pull")

def repositories():
  excludes = native.existing_rules().keys()
  if "java_image_base" not in excludes:
    docker_pull(
      name = "java_image_base",
      registry = "gcr.io",
      repository = "distroless/java",
      # 'latest' circa 2017-09-15
      digest = "sha256:22bd88ce795258f9d976334abcb071a99b1b4fb9229b86e7d085a7114a2dc565",
    )
  if "jetty_image_base" not in excludes:
    docker_pull(
      name = "jetty_image_base",
      registry = "gcr.io",
      repository = "distroless/java/jetty",
      # 'latest' circa 2017-09-15
      digest = "sha256:952fc35b45801e07ff189de1d856efc14256e446bff2617da1fd348434ee4e7b",
    )
  if "servlet_api" not in excludes:
    native.maven_jar(
        name = "javax_servlet_api",
        artifact = "javax.servlet:javax.servlet-api:3.0.1",
    )

load(
    "//docker:docker.bzl",
    _docker = "docker",
)

def java_files(f):
  if hasattr(f, "java"):  # java_library, java_import
    return f.java.transitive_runtime_deps
  if hasattr(f, "files"):  # a jar file
    return f.files
  return []

load(
    "//docker/contrib/common:lang-image.bzl",
    "dep_layer_impl",
    "layer_file_path",
)

def _jar_dep_layer_impl(ctx):
  """Appends a layer for a single dependency's runfiles."""
  return dep_layer_impl(ctx, runfiles=java_files)

_jar_dep_layer = rule(
    attrs = _docker.build.attrs + {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(mandatory = True),

        # Override the defaults.
        "directory": attr.string(default = "/app"),
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
    },
    executable = True,
    outputs = _docker.build.outputs,
    implementation = _jar_dep_layer_impl,
)

def _jar_app_layer_impl(ctx):
  """Appends the app layer with all remaining runfiles."""

  available = depset()
  for jar in ctx.attr.layers:
    available += java_files(jar)

  # We compute the set of unavailable stuff by walking deps
  # in the same way, adding in our binary and then subtracting
  # out what it available.
  unavailable = depset()
  for jar in ctx.attr.deps + ctx.attr.runtime_deps:
    unavailable += java_files(jar)

  unavailable += ctx.attr.binary.files
  unavailable = [x for x in unavailable if x not in available]

  classpath = ":".join([
    layer_file_path(ctx, x) for x in available + unavailable
  ])

  # Classpaths can grow long and there is a limit on the length of a
  # command line, so mitigate this by always writing the classpath out
  # to a file instead.
  classpath_file = ctx.new_file(ctx.attr.name + ".classpath")
  ctx.actions.write(classpath_file, classpath)

  binary_path = layer_file_path(ctx, ctx.files.binary[0])
  classpath_path = layer_file_path(ctx, classpath_file)
  entrypoint = [
      '/usr/bin/java',
      '-cp',
      # Support optionally passing the classpath as a file.
      '@' + classpath_path if ctx.attr._classpath_as_file else classpath,
      ctx.attr.main_class
   ]

  file_map = {
    layer_file_path(ctx, f): f
    for f in unavailable + [classpath_file]
  }

  return _docker.build.implementation(
    ctx,
    # We use all absolute paths.
    directory="/", file_map=file_map,
    entrypoint=entrypoint)

_jar_app_layer = rule(
    attrs = _docker.build.attrs + {
        # The binary target for which we are synthesizing an image.
        "binary": attr.label(mandatory = True),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "layers": attr.label_list(),
        # The rest of the dependencies.
        "deps": attr.label_list(),
        "runtime_deps": attr.label_list(),
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The main class to invoke on startup.
        "main_class": attr.string(mandatory = True),

        # Whether the classpath should be passed as a file.
        "_classpath_as_file": attr.bool(default = False),

        # Override the defaults.
        "directory": attr.string(default = "/app"),
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
        "legacy_run_behavior": attr.bool(default = False),
    },
    executable = True,
    outputs = _docker.build.outputs,
    implementation = _jar_app_layer_impl,
)

def java_image(name, base=None, main_class=None,
               deps=[], runtime_deps=[], layers=[], **kwargs):
  """Builds a Docker image overlaying the java_binary.

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See java_binary.
  """
  binary_name = name + ".binary"

  native.java_binary(name=binary_name, main_class=main_class,
                     # If the rule is turning a JAR built with java_library into
                     # a binary, then it will appear in runtime_deps.  We are
                     # not allowed to pass deps (even []) if there is no srcs
                     # kwarg.
                     deps=(deps + layers) or None, runtime_deps=runtime_deps,
                     **kwargs)

  index = 0
  base = base or "@java_image_base//image"
  for dep in layers:
    this_name = "%s.%d" % (name, index)
    _jar_dep_layer(name=this_name, base=base, dep=dep)
    base = this_name
    index += 1

  _jar_app_layer(name=name, base=base, binary=binary_name,
                 main_class=main_class,
                 deps=deps, runtime_deps=runtime_deps, layers=layers)

def _war_dep_layer_impl(ctx):
  """Appends a layer for a single dependency's runfiles."""
  # TODO(mattmoor): Today we run the risk of filenames colliding when
  # they get flattened.  Instead of just flattening and using basename
  # we should use a file_map based scheme.
  return _docker.build.implementation(
    ctx, files=java_files(ctx.attr.dep),
  )

_war_dep_layer = rule(
    attrs = _docker.build.attrs + {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(mandatory = True),

        # Override the defaults.
        "directory": attr.string(default = "/jetty/webapps/ROOT/WEB-INF/lib"),
        # WE WANT PATHS FLATTENED
        # "data_path": attr.string(default = "."),
    },
    executable = True,
    outputs = _docker.build.outputs,
    implementation = _war_dep_layer_impl,
)

def _war_app_layer_impl(ctx):
  """Appends the app layer with all remaining runfiles."""

  available = depset()
  for jar in ctx.attr.layers:
    available += java_files(jar)

  # This is based on rules_appengine's WAR rules.
  transitive_deps = depset()
  transitive_deps += java_files(ctx.attr.library)

  # TODO(mattmoor): Handle data files.

  # If we start putting libs in servlet-agnostic paths,
  # then consider adding symlinks here.
  files = [d for d in transitive_deps if d not in available]

  return _docker.build.implementation(ctx, files=files)

_war_app_layer = rule(
    attrs = _docker.build.attrs + {
        # The library target for which we are synthesizing an image.
        "library": attr.label(mandatory = True),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "layers": attr.label_list(),
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        "entrypoint": attr.string_list(default = []),

        # Override the defaults.
        "directory": attr.string(default = "/jetty/webapps/ROOT/WEB-INF/lib"),
        # WE WANT PATHS FLATTENED
        # "data_path": attr.string(default = "."),
        "legacy_run_behavior": attr.bool(default = False),
        # Run the container using host networking, so that the service is
        # available to the developer without having to poke around with
        # docker inspect.
        "docker_run_flags": attr.string(
            default = "-i --rm --network=host",
        ),
    },
    executable = True,
    outputs = _docker.build.outputs,
    implementation = _war_app_layer_impl,
)

def war_image(name, base=None, deps=[], layers=[], **kwargs):
  """Builds a Docker image overlaying the java_library as an exploded WAR.

  TODO(mattmoor): For `bazel run` of this to be useful, we need to be able
  to ctrl-C it and have the container actually terminate.  More information:
  https://github.com/bazelbuild/bazel/issues/3519

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See java_library.
  """
  library_name = name + ".library"

  native.java_library(name=library_name, deps=deps + layers, **kwargs)

  index = 0
  base = base or "@jetty_image_base//image"
  for dep in layers:
    this_name = "%s.%d" % (name, index)
    _war_dep_layer(name=this_name, base=base, dep=dep)
    base = this_name
    index += 1

  _war_app_layer(name=name, base=base, library=library_name, layers=layers)
