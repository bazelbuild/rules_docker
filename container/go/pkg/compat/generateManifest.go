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

// TODO (xiaohegong): Move these functions to createImageConfig.go and change pusher logic

// schemaVersion is the schema version of the docker image manifest to generate.
const schemaVersion = 2

// GenerateManifest generates a manifest at the path given by 'dst' for the legacy image in the directory 'src'.
func GenerateManifest(src, dst, configPath string, layersPath []string) (v1.Manifest, error) {
	m, err := buildManifest(configPath, layersPath)
	if err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "unable to construct manifest from %s", src)
	}

	if err := writeManifest(m, dst); err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "unable to write manifest to %s", dst)
	}

	return m, nil
}

// buildManifest takes the directory to image config and an array of directories to the layers and build a manifest object based on the given config and layers.
func buildManifest(configPath string, layersPath []string) (v1.Manifest, error) {
	rawConfig, err := ioutil.ReadFile(configPath)
	if err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "unable to read image config file from %s", configPath)
	}

	cfgHash, cfgSize, err := v1.SHA256(bytes.NewReader(rawConfig))
	if err != nil {
		return v1.Manifest{}, errors.Wrap(err, "unable to hash image config file")
	}

	manifest := v1.Manifest{
		SchemaVersion: schemaVersion,
		MediaType:     types.DockerManifestSchema2,
		Config: v1.Descriptor{
			MediaType: types.DockerConfigJSON,
			Size:      cfgSize,
			Digest:    cfgHash,
		},
	}

	manifest.Layers = make([]v1.Descriptor, len(layersPath))
	for i, l := range layersPath {
		layer, err := tarball.LayerFromFile(l)
		if err != nil {
			return v1.Manifest{}, errors.Wrapf(err, "unable to get layer %d from %s", i, l)
		}

		layerSize, err := layer.Size()
		if err != nil {
			return v1.Manifest{}, err
		}
		layerHash, err := layer.Digest()
		if err != nil {
			return v1.Manifest{}, err
		}

		manifest.Layers[i] = v1.Descriptor{
			MediaType: types.DockerLayer,
			Size:      layerSize,
			Digest:    layerHash,
		}
	}

	return manifest, nil
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
