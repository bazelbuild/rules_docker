"""Custom test and setup properties for checkin pull_info provider."""

load("//container:providers.bzl", "PullInfo")

def _pull_info_validation_test_impl(ctx):
    pull_info = ctx.attr.target[PullInfo]
    compare_script_file = ctx.actions.declare_file("compare.sh")
    compare_script = """#!/usr/bin/env bash
function assert_equals(){
    if [ "$2" != "$3" ]; then
      echo "Expected $1 to be '$2' but was '$3'"
      exit 1
    fi
}
""" + """
assert_equals "base_image_registry" "{expected_registry}" "{actual_registry}"
assert_equals "base_image_repository" "{expected_repository}" "{actual_repository}"
assert_equals "base_image_digest" "{expected_digest}" "{actual_digest}"
echo "PASSED"
""".format(
        expected_registry = ctx.attr.expected_registry,
        actual_registry = pull_info.base_image_registry,
        expected_repository = ctx.attr.expected_repository,
        actual_repository = pull_info.base_image_repository,
        expected_digest = ctx.attr.expected_digest,
        actual_digest = pull_info.base_image_digest,
    )

    ctx.actions.write(compare_script_file, compare_script, is_executable = True)

    return [DefaultInfo(executable = compare_script_file, runfiles = ctx.runfiles(files = [compare_script_file]))]

pull_info_validation_test = rule(
    implementation = _pull_info_validation_test_impl,
    attrs = {
        "expected_digest": attr.string(mandatory = True),
        "expected_registry": attr.string(mandatory = True),
        "expected_repository": attr.string(mandatory = True),
        "target": attr.label(providers = [PullInfo]),
    },
    test = True,
)
