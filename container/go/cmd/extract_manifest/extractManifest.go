// Copyright 2017 The Bazel Authors. All rights reserved.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//    http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License/
////////////////////////////////////
// TODO: This binary implements the ability to
// It expects to be run with:
//     extract_config -tarball=image.tar -output=output.confi
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

var (
	dst = flag.String("dst", "", "The path to the output file where the layers and config are in.")
)

const (
	schemaVersion = 2
)

func main() {
	flag.Parse()
	if *dst == "" {
		log.Fatalf("required option -dst was not specified")
	}

	path := filepath.Dir(*dst)

	imageRunfiles, err := ioutil.ReadDir(path)
	if err != nil {
		log.Fatalf("Error reading legacy image files from %s: %v", path, err)
	}

	var configDir string
	var layersDir []string
	for _, f := range imageRunfiles {
		if strings.Contains(f.Name(), "config") {
			configDir = filepath.Join(path, f.Name())
		} else if strings.Contains(f.Name(), ".tar.gz") {
			layersDir = append(layersDir, filepath.Join(path, f.Name()))
		}
	}

	m, err := buildManifest(configDir, layersDir)
	if err != nil {
		log.Fatalf("unable to construct manifest: %v", err)
	}

	//TODO: write a manifest.json to dst directory
	writeManifest(m, *dst)
}

func buildManifest(configDir string, layersDir []string) (v1.Manifest, error) {
	rawConfig, err := ioutil.ReadFile(configDir)
	if err != nil {
		return v1.Manifest{}, err
	}
	cfgHash, cfgSize, err := v1.SHA256(bytes.NewReader(rawConfig))
	if err != nil {
		return v1.Manifest{}, err
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

	// TODO: errors
	manifest.Layers = make([]v1.Descriptor, len(layersDir))
	for i, l := range layersDir {
		layer, err := tarball.LayerFromFile(l)
		if err != nil {
			return v1.Manifest{}, err
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

func writeManifest(m v1.Manifest, path string) error {
	rawManifest, err := json.Marshal(m)
	if err != nil {
		return err
	}
	err = ioutil.WriteFile(path, rawManifest, os.ModePerm)
	if err != nil {
		return err
	}

	return nil
}
