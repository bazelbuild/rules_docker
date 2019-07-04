/// Copyright 2015 The Bazel Authors. All rights reserved.
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
// Image index for intermediate format used in python containerregistry.
// Uses the go-containerregistry API as backend.

package compat

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

// ImageIndexFromPath is a convenience function which constructs a Path and returns its v1.ImageIndex.
// This expects a intermediate format with manifest.json, config.json and digest exist in the given <path>.
func ImageIndexFromPath(path string) (v1.ImageIndex, error) {
	lp, err := FromPath(path)
	if err != nil {
		return nil, err
	}
	return lp.ImageIndex()
}

// FromPath reads an MM intermediate image index at path and constructs a layout.Path.
// Naively validates this is a valid intermediate layout by checking digest, config.json, and manifest.json exist.
func FromPath(path string) (Path, error) {
	var err error
	_, err = os.Stat(filepath.Join(path, manifestFile))
	if err != nil {
		return "", err
	}

	_, err = os.Stat(filepath.Join(path, configFile))
	if err != nil {
		return "", err
	}

	_, err = os.Stat(filepath.Join(path, digestFile))
	if err != nil {
		return "", err
	}

	return Path(path), nil
}

// This intermediate layout implements v1.ImageIndex.
type intermediateLayout struct {
	// path of this layout, with helper functions for finding the full directory.
	path Path
	// rawManifest is the raw bytes of manifest.json file.
	rawManifest []byte
}

// MediaType of this image index's manifest.
func (i *intermediateLayout) MediaType() (types.MediaType, error) {
	// TODO: This image index does not follow the OCI standards, but the contents are compatible indeed.
	// We will have this image index as an OCIImageIndex type for now, since this is only a intermediate format.
	return types.OCIImageIndex, nil
}

// Digest returns the sha256 hash of this index's manifest.json metadata, an entrypoint for the config and layers.
func (i *intermediateLayout) Digest() (v1.Hash, error) {
	// We expect a file named digest that stores the manifest's hash formatted as sha256:{Hash} in this directory.
	digest, err := ioutil.ReadFile(i.path.path(digestFile))
	if err != nil {
		fmt.Errorf("Failed to locate SHA256 digest file for image manifest: %v", err)
	}

	return v1.NewHash(string(digest))
}

// IndexManifest returns this image index's manifest object.
func (i *intermediateLayout) IndexManifest() (*v1.IndexManifest, error) {
	// Parse raw manifest into a manifest struct.
	manifest, err := partial.Manifest(i)
	if err != nil {
		return nil, fmt.Errorf("Failed to parse raw manifest, please check if a correctly formatted manifest.json exists %v", err)
	}
	manifestDigest, err := i.Digest()
	if err != nil {
		return nil, fmt.Errorf("Failed to parse image manifest hash, please check if a digest file exists in the directory and it is formatted as {Algorithm}:{Hash} %v", err)
	}

	// We are missing index.json in this intermediate format.
	// Since index.json is represented in IndexManifest structure, we will populate this struct with parsed info.
	index := v1.IndexManifest{
		SchemaVersion: manifest.SchemaVersion,
		Manifests: []v1.Descriptor{
			v1.Descriptor{
				MediaType: manifest.MediaType,
				Size:      int64(len(i.rawManifest)),
				Digest:    manifestDigest,
			},
		},
	}

	return &index, nil
}

// RawManifest returns the serialized bytes of manifest.json metadata.
func (i *intermediateLayout) RawManifest() ([]byte, error) {
	if i.rawManifest == nil {
		rawManifest, err := ioutil.ReadFile(i.path.path(manifestFile))
		if err != nil {
			return nil, err
		}
		i.rawManifest = rawManifest
	}

	return i.rawManifest, nil
}

// Image returns a v1.Image that this ImageIndex references.
func (i *intermediateLayout) Image(h v1.Hash) (v1.Image, error) {
	// Iterate through the list of manifests and get the manifest descriptor with digest h.
	desc, err := i.findDescriptor(h)
	if err != nil {
		return nil, err
	}

	if !isExpectedMediaType(desc.MediaType, types.OCIManifestSchema1, types.DockerManifestSchema2) {
		return nil, fmt.Errorf("unexpected media type for %v: %s", h, desc.MediaType)
	}

	img := &layoutImage{
		path: i.path,
		desc: *desc,
	}

	return partial.CompressedToImage(img)
}

// findDescriptor looks for the manifest with digest h in our "index.json" struct and returns its descriptor.
func (i *intermediateLayout) findDescriptor(h v1.Hash) (*v1.Descriptor, error) {
	im, err := i.IndexManifest()
	if err != nil {
		return nil, err
	}

	for _, desc := range im.Manifests {
		if desc.Digest == h {
			return &desc, nil
		}
	}

	return nil, fmt.Errorf("could not find descriptor in index: %s", h)
}

// ImageIndex constructs a v1.ImageIndex that this ImageIndex references.
func (i *intermediateLayout) ImageIndex(h v1.Hash) (v1.ImageIndex, error) {
	// Iterate through the list of manifests and get the manifest descriptor with digest h.
	desc, err := i.findDescriptor(h)
	if err != nil {
		return nil, err
	}

	if !isExpectedMediaType(desc.MediaType, types.OCIImageIndex, types.DockerManifestList) {
		return nil, fmt.Errorf("unexpected media type for %v: %s", h, desc.MediaType)
	}

	return &intermediateLayout{
		path:        i.path,
		rawManifest: i.rawManifest,
	}, nil
}

// isExpectedMediaType returns whether the given mediatype mt is allowed.
func isExpectedMediaType(mt types.MediaType, expected ...types.MediaType) bool {
	for _, allowed := range expected {
		if mt == allowed {
			return true
		}
	}
	return false
}
