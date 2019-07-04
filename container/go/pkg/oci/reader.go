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
package oci

import (
	"fmt"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/layout"
	"github.com/google/go-containerregistry/pkg/v1/validate"
	"github.com/pkg/errors"
)

// Read returns a docker image referenced by the given idx. The image index should have been written by "Write" or outputted by container_pull.
// NOTE: this only reads index with a single image.
func Read(idx v1.ImageIndex) (v1.Image, error) {
	manifest, err := idx.IndexManifest()
	if err != nil {
		return nil, errors.Wrapf(err, "unable to parse manifest metadata from the given image index")
	}

	// Read the contents of the layout -- we expect to find a single image.
	// TODO (xiaohegong): We do not expect to push multiple manifests for now, e.g., a manifest list, since it will be resolved to a image for one platform. This case might need to be handled later.
	if len(manifest.Manifests) > 1 {
		return nil, fmt.Errorf("got %d manifests, want 1", len(manifest.Manifests))
	}

	// Read that single image as a v1.Image and return it.
	digest := manifest.Manifests[0].Digest

	img, err := idx.Image(digest)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to load image with digest %s obtained from the manifest", digest)
	}

	if err := validate.Image(img); err != nil {
		return nil, errors.Wrapf(err, "unable to load image with digest %s due to invalid image index format", digest)
	}

	return img, nil
}

// ReadIndex reads a OCI image layout or legacy image index into a ImageIndex object.
// The image in the given path <src> follows the OCI Image Layout or the legacy image layout (outputted by container_pull).
// (https://github.com/opencontainers/image-spec/blob/master/image-layout.md#oci-image-layout-specification)
// Specifically, <src> must contains "index.json" that servers as an entrypoint for the contained image for a OCI layout. <src> must contains manifest.json, config.json and a digest file for a legacy image layout.
func ReadIndex(src, format string) (v1.ImageIndex, error) {
	if format == "oci" {
		idx, err := layout.ImageIndexFromPath(src)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to read OCI image index from %s", src)
		}
		return idx, nil
	}

	// Read a mm intermediate layout otherwise, expect manifest.json, config.json and digest at src.
	idx, err := compat.ImageIndexFromPath(src)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to read MM image index from %s", src)
	}

	return idx, nil
}
