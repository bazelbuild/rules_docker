# bazel_integration_test

This package provides a test runner that can run bazel-in-bazel.

This allows us to:

- test rules_docker with a different version of Bazel than we use ourselves, allowing testing
  against both LTS and rolling releases for example
- create test fixtures which are fully-formed user WORKSPACEs, giving us test coverage for
  what repository rules users need when consuming our distribution archive
- easily create self-contained reproductions of user issues, and test these against HEAD
