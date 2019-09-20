# Copyright 2017 The Bazel Authors. All rights reserved.
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
"""
packages_metadata accepts a csv file with the columns "Name" & "Version" where
Name is the name of the software package and Version is the version string
of the package. The rule will produce a YAML output with the information from
the CSV organized as follows:
packages:
    - name: package1
      version: version1
    - name: package2
      version: version2
    ...
"""

def _impl(ctx):
    args = ctx.actions.args()
    args.add("-inputCSV", ctx.file.metadata_csv)
    args.add("-outputYAML", ctx.outputs.yaml)
    ctx.actions.run(
        inputs = [ctx.file.metadata_csv],
        outputs = [ctx.outputs.yaml],
        executable = ctx.executable._converter,
        arguments = [args],
        mnemonic = "PackagesMetadataYAML",
    )

packages_metadata = rule(
    attrs = {
        "metadata_csv": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "_converter": attr.label(
            default = "@io_bazel_rules_docker//contrib/go/cmd/packages_metadata",
            cfg = "host",
            executable = True,
        ),
    },
    outputs = {
        "yaml": "%{name}.yaml",
    },
    implementation = _impl,
)
