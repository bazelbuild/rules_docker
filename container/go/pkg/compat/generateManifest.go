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
// Path utils used for legacy image layout outputted by python containerregistry.
// Uses the go-containerregistry API as backend.

package compat

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

// schemaVersion is the schema version of the docker image manifest to generate.
const schemaVersion = 2

// GenerateManifest generate a manifest.json metadata by reading a config.json file and layer tarballs from src to dst.
func GenerateManifest(src, dst string) (v1.Manifest, error) {
	var configDir string
	var layersDir []string

	imageRunfiles, err := ioutil.ReadDir(src)
	if err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "Error reading legacy image files from %s", src)
	}

	for _, f := range imageRunfiles {
		if strings.Contains(f.Name(), "manifest.json") {
			// The manifest already exist
			return v1.Manifest{}, nil
		} else if strings.Contains(f.Name(), "config") {
			configDir = filepath.Join(src, f.Name())
		} else if strings.Contains(f.Name(), ".tar.gz") {
			layersDir = append(layersDir, filepath.Join(src, f.Name()))
		}
	}

	m, err := buildManifest(configDir, layersDir)
	if err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "unable to construct manifest from %s", src)
	}

	err = writeManifest(m, dst)
	if err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "unable to write manifest to %s", dst)
	}

	return m, nil
}

// buildManifest takes the directory to config.json and an array of directories to the layers and build a manifest object based on the given config and layers.
func buildManifest(configDir string, layersDir []string) (v1.Manifest, error) {
	rawConfig, err := ioutil.ReadFile(configDir)
	if err != nil {
		return v1.Manifest{}, errors.Wrapf(err, "Unable to read config.json file from %s", configDir)
	}

	cfgHash, cfgSize, err := v1.SHA256(bytes.NewReader(rawConfig))
	if err != nil {
		return v1.Manifest{}, errors.Wrap(err, "Unable to hash config.json file")
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

	manifest.Layers = make([]v1.Descriptor, len(layersDir))
	for i, l := range layersDir {
		layer, err := tarball.LayerFromFile(l)
		if err != nil {
			return v1.Manifest{}, errors.Wrapf(err, "Unable to get layer %d from %s", i, l)
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

// writeManifest takes a Manifest object and writes a JSON file to the given manifest.json path.
func writeManifest(m v1.Manifest, path string) error {
	rawManifest, err := json.Marshal(m)
	if err != nil {
		return errors.Wrap(err, "Unable to get the JSON encoding of manifest")
	}

	err = ioutil.WriteFile(path, rawManifest, os.ModePerm)
	if err != nil {
		return errors.Wrapf(err, "Unable to write manifest to path %s", path)
	}

	return nil
}
