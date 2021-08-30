"""Pinned version info"""

# Currently used Bazel version. This version is what the rules here are tested
# against.
# This version should be updated together with the version of the Bazel
# in .bazelversion.
# TODO(alexeagle): assert this is the case in a test
BAZEL_VERSION = "4.0.0"

# Versions of Bazel which users should be able to use.
# Ensures we don't break backwards-compatibility,
# accidentally forcing users to update their LTS-supported bazel.
# These are the versions used when testing nested workspaces with
# bazel_integration_test.
SUPPORTED_BAZEL_VERSIONS = [
    # TODO: add rolling release of Bazel, or other LTS when they exist
    BAZEL_VERSION,
]
