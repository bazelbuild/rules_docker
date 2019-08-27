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
	"github.com/pkg/errors"
)

// Expected metadata files in legacy layout.
const manifestFile = "manifest.json"

// LayerOpts instructs the legacy image image on how to read a layer.
type LayerOpts struct {
	// Layer directly represents a v1.Layer. If this field is specified, all
	// other fields are ignored.
	Layer v1.Layer
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
	return partial.CompressedToImage(&legacyImage{
		configPath: configPath,
		layers:     layers,
	})
}

// ReadWithBaseTarball returns a Image object with tarball at tarballPath as base and layers appended from layersPath.
func ReadWithBaseTarball(tarballPath string, layersPath []string) (v1.Image, error) {
	img, err := tarball.ImageFromPath(tarballPath, nil)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to parse image from tarball at %s", tarballPath)
	}
	for _, l := range layersPath {
		layer, err := tarball.LayerFromFile(l)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to get layer from %s", l)
		}

		img, err = mutate.AppendLayers(img, layer)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to append layer at %s to image", l)
		}
	}
	return img, nil

}
