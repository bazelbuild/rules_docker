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

TODO(mattmoor): java_image

The signature of war_image is compatible with java_library.
"""

load("//docker:pull.bzl", "docker_pull")

def repositories():
  excludes = native.existing_rules().keys()
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
    "//docker:build.bzl",
    _build_attrs = "attrs",
    _build_implementation = "implementation",
    _build_outputs = "outputs",
)
load("@subpar//:debug.bzl", "dump")

def _war_dep_layer_impl(ctx):
  """Appends a layer for a single dependency's runfiles."""

  transitive_deps = set()
  if hasattr(ctx.attr.dep, "java"):  # java_library, java_import
    transitive_deps += ctx.attr.dep.java.transitive_runtime_deps
  elif hasattr(ctx.attr.dep, "files"):  # a jar file
    transitive_deps += ctx.attr.dep.files

  # This path could be more context agnostic, but with defaults
  # the name doesn't change, so this is good enough for now.
  directory = ctx.attr.directory + "/" + ctx.attr.servlet + "/WEB-INF/lib"
  return _build_implementation(
    ctx,
    directory=directory,
    files=list(transitive_deps),
  )

_war_dep_layer = rule(
    attrs = _build_attrs + {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(mandatory = True),
        "servlet": attr.string(default = "ROOT"),

        # Override the defaults.
        "directory": attr.string(default = "/jetty/webapps/"),
        # WE WANT PATHS FLATTENED
        # "data_path": attr.string(default = "."),
    },
    executable = True,
    outputs = _build_outputs,
    implementation = _war_dep_layer_impl,
)

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

  directory = ctx.attr.directory + "/" + ctx.attr.servlet + "/WEB-INF/lib"

  files = []
  for d in transitive_deps:
    if d not in available:
      # If we start putting libs in servlet-agnostic paths,
      # then consider adding symlinks here.
      files += [d]

  return _build_implementation(
    ctx, files=files,
    directory=directory)

_war_app_layer = rule(
    attrs = _build_attrs + {
        # The library target for which we are synthesizing an image.
        "library": attr.label(mandatory = True),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "layers": attr.label_list(),
        "servlet": attr.string(default = "ROOT"),
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        "entrypoint": attr.string_list(default = []),

        # Override the defaults.
        "directory": attr.string(default = "/jetty/webapps/"),
        # WE WANT PATHS FLATTENED
        # "data_path": attr.string(default = "."),
    },
    executable = True,
    outputs = _build_outputs,
    implementation = _war_app_layer_impl,
)

def war_image(name, deps=[], layers=[], **kwargs):
  """Builds a Docker image overlaying the java_library as an exploded WAR.

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See java_library.
  """
  library_name = name + ".library"

  native.java_library(name=library_name, deps=deps + layers, **kwargs)

  index = 0
  base = "@jetty_image_base//image"
  for dep in layers:
    this_name = "%s.%d" % (name, index)
    _war_dep_layer(name=this_name, base=base, dep=dep)
    base = this_name
    index += 1

  _war_app_layer(name=name, base=base, library=library_name, layers=layers)
