"""Top level extensions to download stuff.
"""

load("//container:extensions.bzl", _container = "container")
load("//repositories:download_binaries.bzl", _download_go_puller = "download_go_puller", _download_structure_test = "download_structure_test")
load("//toolchains/docker:extensions.bzl", _docker_toolchain = "docker_toolchain")

container = _container
docker_toolchain = _docker_toolchain

def _download_go_puller_impl(_ctx):
    _download_go_puller()

download_puller = module_extension(
    implementation = _download_go_puller_impl,
)

def _download_structure_test_impl(_ctx):
    _download_structure_test()

download_structure_test = module_extension(
    implementation = _download_structure_test_impl,
)
