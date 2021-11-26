"Helper for determining when to stamp build outputs"

load("@io_bazel_rules_docker//container:providers.bzl", "StampSettingInfo")

def _impl(ctx):
    return [StampSettingInfo(value = ctx.attr.stamp)]

# Modelled after go_context_data in rules_go
# Works around github.com/bazelbuild/bazel/issues/1054
stamp_setting = rule(
    implementation = _impl,
    attrs = {
        "stamp": attr.bool(mandatory = True),
    },
    doc = """Determines whether build outputs should be stamped with version control info.
    
    Stamping causes outputs to be non-deterministic, resulting in cache misses.""",
)
