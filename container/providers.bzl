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

# A provider containing information about a container bundle
BundleInfo = provider(fields = ["container_images", "stamp"])

# A provider identifying container_flatten rules
FlattenInfo = provider()

# A provider containing information needed in container_push and other rules
ImageInfo = provider(fields = ["container_parts"])

# A provider containing information needed in container_push and other rules
ImportInfo = provider(fields = ["container_parts"])

# A provider containing information needed in container_image and other rules.
LayerInfo = provider(fields = [
    "zipped_layer",
    "blob_sum",
    "unzipped_layer",
    "diff_id",
    "env",
])

# A provier identifying container_push rules
PushInfo = provider(fields = [
  "registry", 
  "repository", 
  "tag",
  "stamp",
  "stamp_inputs",
])

