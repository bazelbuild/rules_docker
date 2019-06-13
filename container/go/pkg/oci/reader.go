// Copyright 2015 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//////////////////////////////////////////////////////////////////////
// Reads an OCI image layout on disk.
// https://github.com/opencontainers/image-spec/blob/master/image-layout.md
package reader

import (
	"log"

	v1 "github.com/google/go-containerregistry/pkg/v1"

	"github.com/google/go-containerregistry/pkg/v1/layout"
)

// Read gets and returns the image in the given path <src> that follows the OCI Image Layout.
// (https://github.com/opencontainers/image-spec/blob/master/image-layout.md#oci-image-layout-specification)
// Specifically, <src> must contains "index.json" that servers as an entrypoint for the contained image.
// The image content and configs must be non-empty and stored in <src>/blobs/<SHAxxx>/.
// NOTE: this only reads index with a single image.
func Read(src string) v1.Image {
	// Open the layout at /src as an Image Index.
	idx, err := layout.ImageIndexFromPath(src)
	if err != nil {
		log.Fatal(err)
	}

	// Read the contents of the layout -- we expect to find a single image.
	// TODO (xiaohegong): handle case with multiple manifests.
	manifest, err := idx.IndexManifest()
	if err != nil {
		log.Fatal(err)
	}

	if len(manifest.Manifests) > 1 {
		log.Fatalf("found %d manifests, expected 1", len(manifest.Manifests))
	}

	// Read that single image as a v1.Image and return it.
	digest := manifest.Manifests[0].Digest

	img, err := idx.Image(digest)
	if err != nil {
		log.Fatal(err)
	}
	return img
}
