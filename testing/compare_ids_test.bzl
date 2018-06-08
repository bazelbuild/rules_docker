# Copyright 2015 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

def compare_ids_test(name, tars, timeout = "short", flaky = True):
  """
  Macro which produces a test to compare the ids of a list of image tarballs

  Args:
    name: A unique name for the rule
    tars: List of Label, the list of image tarballs we are comparing
    timeout: Used for *_test timeout attribute
    flaky: Used for *_test flaky attribute

  Refer to https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes-tests
  for refrence about the last two arguments

  This test will succeed if all tarball targets given in argument 'tars' have
  the same id, and will fail otherwise. Useful for testing reproducibilty in
  builds.

  NOTE: All tarballs in the 'tars' argument must contain '.tar' or else they
  will be ignored.
  """

  native.sh_test(
    name = name,
    srcs = ["compare_ids_test.sh"],
    data = tars,
    flaky = flaky,
    timeout = timeout,
  )
