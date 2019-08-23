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
// Generates manifest based on config and layers.

package compat

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"os"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

// GenerateManifest generates a manifest at the path given by 'dst' for the legacy image constructed from config and layers at configPath and layersPath.
func GenerateManifest(dst, configPath string, layersPath []string) (v1.Manifest, error) {
	m, _, err := buildManifest(configPath, layersPath)
	if err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "unable to construct manifest from config at %s", configPath)
	}

	if err := writeManifest(m, dst); err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "unable to write manifest to %s", dst)
	}

	return m, nil
}

// buildManifest takes the directory to image config and an array of directories
// to the layers and build a manifest object based on the given config and
// layers. Also returns a map from the layer digest to the diff ID because the
// manifest object itself doesn't store this information.
func buildManifest(configPath string, layersPath []string) (v1.Manifest, map[string]string, error) {
	rawConfig, err := ioutil.ReadFile(configPath)
	if err != nil {
		return v1.Manifest{}, nil, errors.Wrapf(err, "unable to read image config file from %s", configPath)
	}

	cfgHash, cfgSize, err := v1.SHA256(bytes.NewReader(rawConfig))
	if err != nil {
		return v1.Manifest{}, nil, errors.Wrap(err, "unable to hash image config file")
	}

	manifest := v1.Manifest{
		SchemaVersion: 2,
		MediaType:     types.DockerManifestSchema2,
		Config: v1.Descriptor{
			MediaType: types.DockerConfigJSON,
			Size:      cfgSize,
			Digest:    cfgHash,
		},
	}

	layerDigestToDiffID := make(map[string]string)

	manifest.Layers = make([]v1.Descriptor, len(layersPath))
	for i, l := range layersPath {
		layer, err := tarball.LayerFromFile(l)
		if err != nil {
			return v1.Manifest{}, nil, errors.Wrapf(err, "unable to get layer %d from %s", i, l)
		}

		layerSize, err := layer.Size()
		if err != nil {
			return v1.Manifest{}, nil, errors.Wrap(err, "unable to get size of layer")
		}
		layerHash, err := layer.Digest()
		if err != nil {
			return v1.Manifest{}, nil, errors.Wrap(err, "unable to get digest of layer")
		}
		layerDiff, err := layer.DiffID()
		if err != nil {
			return v1.Manifest{}, nil, errors.Wrap(err, "unable to get DiffID of layer")
		}

		manifest.Layers[i] = v1.Descriptor{
			MediaType: types.DockerLayer,
			Size:      layerSize,
			Digest:    layerHash,
		}
		layerDigestToDiffID[layerHash.Hex] = layerDiff.Hex
	}

	return manifest, layerDigestToDiffID, nil
}

// writeManifest takes a Manifest object and writes a JSON file to the given image manifest path.
func writeManifest(m v1.Manifest, path string) error {
	rawManifest, err := json.Marshal(m)
	if err != nil {
		return errors.Wrap(err, "unable to get the JSON encoding of manifest")
	}

	err = ioutil.WriteFile(path, rawManifest, os.ModePerm)
	if err != nil {
		return errors.Wrapf(err, "unable to write manifest to path %s", path)
	}

	return nil
}
