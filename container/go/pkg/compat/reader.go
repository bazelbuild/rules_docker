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
// Reads an legacy image layout on disk.
package compat

import (
	"fmt"
	"io/ioutil"
	"path/filepath"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/validate"
	"github.com/pkg/errors"
)

// Read returns a docker image referenced by the legacy intermediate layout at src. The image index should have been outputted by container_pull.
// NOTE: this only reads index with a single image.
func Read(src string) (v1.Image, error) {
	_, err := isValidLegacylayout(src)
	if err != nil {
		return nil, errors.Wrapf(err, "invalid legacy layout at %s, requires manifest.json, config.json and digest files", src)
	}

	digest, err := getManifestDigest(src)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to get manifest digest from %s", src)
	}

	// Constructs and validates a v1.Image object.
	legacyImg := &legacyImage{
		path:   src,
		digest: digest,
	}

	img, err := partial.CompressedToImage(legacyImg)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to load image with digest %s obtained from the manifest at %s", digest, src)
	}

	if err := validate.Image(img); err != nil {
		return nil, errors.Wrapf(err, "unable to load image with digest %s due to invalid legacy layout format from %s", digest, src)
	}

	return img, nil
}

// Get the hash of the image to read at <path> from digest file.
func getManifestDigest(path string) (v1.Hash, error) {
	// We expect a file named digest that stores the manifest's hash formatted as sha256:{Hash} in this directory.
	digest, err := ioutil.ReadFile(filepath.Join(path, digestFile))
	if err != nil {
		return v1.Hash{}, fmt.Errorf("failed to locate SHA256 digest file for image manifest: %v", err)
	}

	return v1.NewHash(string(digest))
}
