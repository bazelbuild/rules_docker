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
package compat

import (
	"bytes"
	"encoding/json"
	"fmt"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

type imageIndex struct {
	platforms   []v1.Platform
	images      []v1.Image
	manifest    *v1.IndexManifest
	rawManifest []byte
	digest      v1.Hash
}

// Ensure imageIndex implements the v1.ImageIndex interface.
var _ v1.ImageIndex = (*imageIndex)(nil)

// NewImageIndex creates a new image index from the given list of platforms and images.
func NewImageIndex(platforms []v1.Platform, images []v1.Image) (v1.ImageIndex, error) {
	if len(platforms) != len(images) {
		return nil, fmt.Errorf("list of platforms and images must have the same number of entries")
	}

	ii := imageIndex{
		platforms: platforms,
		images:    images,
	}

	manifests := make([]v1.Descriptor, len(ii.images))
	for idx, image := range ii.images {
		mediaType, err := image.MediaType()
		if err != nil {
			return nil, fmt.Errorf("can't get media type of image %s: %v", image, err)
		}

		size, err := image.Size()
		if err != nil {
			return nil, fmt.Errorf("can't get size of image %s: %v", image, err)
		}

		digest, err := image.Digest()
		if err != nil {
			return nil, fmt.Errorf("can't get digest of image %s: %v", image, err)
		}

		platform := ii.platforms[idx]

		manifests[idx] = v1.Descriptor{
			MediaType: mediaType,
			Size:      size,
			Digest:    digest,
			Platform:  &platform,
		}
	}

	ii.manifest = &v1.IndexManifest{
		SchemaVersion: 2,
		MediaType:     types.DockerManifestList,
		Manifests:     manifests,
	}

	rawManifest, err := json.Marshal(ii.manifest)
	if err != nil {
		return nil, fmt.Errorf("unable to encode generate manifest to JSON: %v", err)
	}

	ii.rawManifest = rawManifest

	// No possible error here
	ii.digest, _, _ = v1.SHA256(bytes.NewReader(ii.rawManifest))

	return &ii, nil
}

// MediaType of this image's manifest.
func (ii *imageIndex) MediaType() (types.MediaType, error) {
	return ii.manifest.MediaType, nil
}

// Digest returns the sha256 of this index's manifest.
func (ii *imageIndex) Digest() (v1.Hash, error) {
	return ii.digest, nil
}

// Size returns the size of the manifest.
func (ii *imageIndex) Size() (int64, error) {
	return int64(len(ii.rawManifest)), nil
}

// IndexManifest returns this image index's manifest object.
func (ii *imageIndex) IndexManifest() (*v1.IndexManifest, error) {
	return ii.manifest, nil
}

// RawManifest returns the serialized bytes of IndexManifest().
func (ii *imageIndex) RawManifest() ([]byte, error) {
	return ii.rawManifest, nil
}

// Image returns a v1.Image that this ImageIndex references.
func (ii *imageIndex) Image(h v1.Hash) (v1.Image, error) {
	for _, image := range ii.images {
		d, err := image.Digest()
		if err != nil {
			return nil, fmt.Errorf("can't get digest of image %s: %v", image, err)
		}

		if h == d {
			return image, nil
		}
	}

	return nil, fmt.Errorf("image not found with ref %s", h)
}

// ImageIndex returns a v1.ImageIndex that this ImageIndex references.
func (ii *imageIndex) ImageIndex(h v1.Hash) (v1.ImageIndex, error) {
	return nil, fmt.Errorf("nested image index is not supported")
}
