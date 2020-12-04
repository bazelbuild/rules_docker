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
"""Provider definitions"""

# A provider containing information exposed by container_bundle rules
BundleInfo = provider(fields = [
    "container_images",
    "stamp",
])

# A provider containing information exposed by container_flatten rules
FlattenInfo = provider()

# A provider containing information exposed by container_image rules
ImageInfo = provider(fields = [
    "container_parts",
    "legacy_run_behavior",
    "docker_run_flags",
    "stamp",
])

# A provider containing information exposed by container_import rules
ImportInfo = provider(fields = ["container_parts"])

# A provider container information exposed by container_pull rules
PullInfo = provider(fields = [
    "base_image_registry",
    "base_image_repository",
    "base_image_digest",
])

# A provider containing information exposed by container_layer rules
LayerInfo = provider(fields = [
    "zipped_layer",
    "blob_sum",
    "unzipped_layer",
    "diff_id",
    "env",
])

# A provider containing information exposed by container_push rules
PushInfo = provider(fields = [
    "registry",
    "repository",
    "tag",
    "stamp",
    "stamp_inputs",
    "digest",
])

# A provider containing information exposed by filter_layer rules
FilterLayerInfo = provider(
    fields = {
        "filtered_depset": "a filtered depset of struct(target=<target>, target_deps=<depset>)",
        "runfiles": "filtered runfiles that should be installed from this layer",
    },
)

# A provider containing information exposed by filter_aspect
FilterAspectInfo = provider(
    fields = {
        "depset": "a depset of struct(target=<target>, target_deps=<depset>)",
    },
)
