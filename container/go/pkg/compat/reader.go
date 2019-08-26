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

	"github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/google/go-containerregistry/pkg/v1/validate"
	"github.com/pkg/errors"
)

// Expected metadata files in legacy layout.
const manifestFile = "manifest.json"

// LayerOpts instructs the legacy image image on how to read a layer.
type LayerOpts struct {
	// Type is the media type of the layer.
	Type types.MediaType
	// Path is the path to the layer tarball. Can be left unspecified for
	// foreign layers.
	Path string
	// DiffID is the layer diffID. Only required for foreign layers. Ignored
	// for every other layer type.
	DiffID string
	// Digest is the layer digest. Only required for foreign layers. Ignored
	// for every other layer type.
	Digest string
	// Size is the size of the layer. Only required for foreign layers. Ignored
	// for every other layer type.
	Size int64
	// URLS is the url to down the layer blob from. Only required for foreign
	// layers. Ignored for every other layer type.
	URLS []string
}

// Read returns a docker image referenced by the legacy intermediate layout with
// the image config and layer tarballs at the given paths.
// NOTE: this only reads index with a single image.
func Read(configPath string, layers []LayerOpts) (v1.Image, error) {
	// Constructs and validates a v1.Image object.
	legacyImg := &legacyImage{
		configPath: configPath,
		layers:     layers,
	}

	img, err := partial.CompressedToImage(legacyImg)
	if err != nil {
		return nil, err
	}

	if err := validate.Image(img); err != nil {
		return nil, errors.Wrapf(err, "unable to validate loaded image")
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
