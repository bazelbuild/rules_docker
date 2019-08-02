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
	"github.com/google/go-containerregistry/pkg/v1/mutate"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/validate"
	"github.com/pkg/errors"
)

// Expected metadata files in legacy layout.
const manifestFile = "manifest.json"

// Read returns a docker image referenced by the legacy intermediate layout at src with given layer tarball paths.
// NOTE: this only reads index with a single image.
func Read(src, configPath string, layers []string) (v1.Image, error) {
	// Constructs and validates a v1.Image object.
	legacyImg := &legacyImage{
		path:       src,
		configPath: configPath,
		layersPath: layers,
	}

	img, err := partial.CompressedToImage(legacyImg)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to load image obtained from %s", src)
	}

	if err := validate.Image(img); err != nil {
		return nil, errors.Wrapf(err, "unable to load image at %s due to invalid legacy layout format", src)
	}

	return img, nil
}

// ReadWithBaseTarball returns a Image object with tarball at tarballPath as base and layers appended from layersPath.
func ReadWithBaseTarball(tarballPath string, layersPath []string) (v1.Image, error) {
	base, err := tarball.ImageFromPath(tarballPath, nil)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to parse image from tarball at %s", tarballPath)
	}

	var newImage = base

	for i, l := range layersPath {
		layer, err := tarball.LayerFromFile(l)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to get layer %d from %s", i, l)
		}

		newImage, err = mutate.AppendLayers(base, layer)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to append layer %d to base tarball", i)
		}
	}

	return newImage, nil

}
