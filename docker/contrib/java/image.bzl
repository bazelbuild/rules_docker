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
      # 'latest' circa 2017-08-04
      digest = "sha256:786ae0562da4c6043f1d0dab513de108d645728bb09691acc8fdd1e05f745d8e",
    )
  if "jetty_image_base" not in excludes:
    docker_pull(
      name = "jetty_image_base",
      registry = "gcr.io",
      repository = "distroless/java/jetty",
      # 'latest' circa 2017-08-04
      digest = "sha256:09dfe023367b743ee01ec5e51245014ba1b43c1a4f5ff7a314be821e7314baf1",
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
load("//docker:build.bzl", "magic_path")

def _dep_layer_impl(ctx):
  """Appends a layer for a single dependency's runfiles."""

  transitive_deps = set()
  if hasattr(ctx.attr.dep, "java"):  # java_library, java_import
    transitive_deps += ctx.attr.dep.java.transitive_runtime_deps
  elif hasattr(ctx.attr.dep, "files"):  # a jar file
    transitive_deps += ctx.attr.dep.files

  directory = ctx.attr.directory
  if ctx.attr.data_path == ".":
    # This signifies that we are preserving paths (JAR)
    # vs. collapsing things (WAR).  For more info see:
    # https://github.com/bazelbuild/bazel/issues/2176
    directory += "/" + ctx.label.package
  return _docker.build.implementation(
    ctx,
    directory=directory,
    files=list(transitive_deps),
  )

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
    implementation = _dep_layer_impl,
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
    implementation = _dep_layer_impl,
)

def _jar_app_layer_impl(ctx):
  """Appends the app layer with all remaining runfiles."""

  available = set()
  for jar in ctx.attr.layers:
    if hasattr(jar, "java"):  # java_library, java_import
      available += jar.java.transitive_runtime_deps
    elif hasattr(jar, "files"):  # a jar file
      available += jar.files

  # We compute the set of unavailable stuff by walking deps
  # in the same way, adding in our binary and then subtracting
  # out what it available.
  unavailable = set()
  for jar in ctx.attr.deps + ctx.attr.runtime_deps:
    if hasattr(jar, "java"):  # java_library, java_import
      unavailable += jar.java.transitive_runtime_deps
    elif hasattr(jar, "files"):  # a jar file
      unavailable += jar.files

  unavailable += ctx.attr.binary.files
  unavailable = [x for x in unavailable if x not in available]
  directory = ctx.attr.directory + "/" + ctx.label.package
  files = unavailable

  classpath = ":".join([
    directory + "/" + magic_path(ctx, x)
    for x in available + unavailable
  ])
  binary_path = directory + "/" + magic_path(ctx, ctx.files.binary[0])
  entrypoint = ['/usr/bin/java', '-cp', classpath, ctx.attr.main_class]

  return _docker.build.implementation(
    ctx, files=files, entrypoint=entrypoint, directory=directory)

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

        # Override the defaults.
        "directory": attr.string(default = "/app"),
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
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

def _war_app_layer_impl(ctx):
  """Appends the app layer with all remaining runfiles."""

  available = set()
  for jar in ctx.attr.layers:
    if hasattr(jar, "java"):  # java_library, java_import
      available += jar.java.transitive_runtime_deps
    elif hasattr(jar, "files"):  # a jar file
      available += jar.files

  # This is based on rules_appengine's WAR rules.
  transitive_deps = set()
  if hasattr(ctx.attr.library, "java"):  # java_library, java_import
    transitive_deps += ctx.attr.library.java.transitive_runtime_deps
  elif hasattr(ctx.attr.library, "files"):  # a jar file
    transitive_deps += ctx.attr.library.files

  # TODO(mattmoor): Handle data files.

  files = []
  for d in transitive_deps:
    if d not in available:
      # If we start putting libs in servlet-agnostic paths,
      # then consider adding symlinks here.
      files += [d]

  return _docker.build.implementation(
    ctx, files=files, directory=ctx.attr.directory)

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
    },
    executable = True,
    outputs = _docker.build.outputs,
    implementation = _war_app_layer_impl,
)

def war_image(name, base=None, deps=[], layers=[], **kwargs):
  """Builds a Docker image overlaying the java_library as an exploded WAR.

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
