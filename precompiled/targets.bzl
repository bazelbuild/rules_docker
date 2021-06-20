"""
Generates a list of targets for the GOOS + GOARCH platforms we
support in rules_docker.
"""

ARCHS = [
    "darwin_amd64",
    "linux_amd64",
    "linux_arm64",
    "linux_s390x",
    "windows_amd64",
]

def targets():
    """Generates a list of targets for all of the precompiled puller/loader binaries.

    Returns:
      List of all precompiled puller/pusher binary files.
    """
    targets = []
    for arch in ARCHS:
        ext = "" if "windows" not in arch else ".exe"
        targets += ["@io_bazel_rules_docker//precompiled/%s:%s%s" % (arch, target, ext) for target in ("puller", "loader")]
    return targets
