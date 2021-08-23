#Public API for doc generation
#Same as container.bzl, but intended for use by stardoc.
#Instead of importing wrapper macros, we import rules directly so that their attributes are documented, not
#an opaque **kwargs pass-through.
"""
Generated API documentation for rules that manipulating containers.

Load these from `@io_bazel_rules_docker//container:container.bzl`.
"""

load("//container:bundle.bzl", _container_bundle = "container_bundle_")
load("//container:flatten.bzl", _container_flatten = "container_flatten")
load("//container:image.bzl", _container_image = "container_image", _image = "image")
load("//container:import.bzl", _container_import = "container_import")
load("//container:layer.bzl", _container_layer = "container_layer_")
load("//container:load.bzl", _container_load = "container_load")
load("//container:pull.bzl", _container_pull = "container_pull")
load("//container:push.bzl", _container_push = "container_push_")

# Explicitly re-export the functions
container_bundle = _container_bundle
container_flatten = _container_flatten
container_image = _container_image
image = _image
container_layer = _container_layer
container_import = _container_import
container_pull = _container_pull
container_push = _container_push
container_load = _container_load
