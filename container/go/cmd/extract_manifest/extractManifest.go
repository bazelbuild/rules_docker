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
	"flag"
	"fmt"
	"io/ioutil"
	"path"
	"strings"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

var (
	dstDir    = flag.String("dst", "", "The path to the output file where the layers, config and manifest will be written to.")
	files     = flag.String("files", "", "The path to the input files.")
	configDir string
	layersDir []string
)

// Extension for layers and config files that are made symlinks
const (
	compressedLayerExt = ".tar.gz"
	legacyConfigFile   = "config.json"
	legacyManifestFile = "manifest.json"
	schemaVersion      = 2
)

func main() {
	flag.Parse()

	if *dstDir == "" {
		fmt.Errorf("required option -dst was not specified")
	}
	if *files == "" {
		fmt.Errorf("required option -files was not specified")
	}

	counter := 0
	imageRunfiles := strings.Split(*files, " ")

	for _, f := range imageRunfiles {
		if strings.Contains(f, "config") {
			configDir := path.Join(*dstDir, legacyConfigFile)
			if err := compat.GenerateSymlinks(f, configDir); err != nil {
				fmt.Errorf("failed to generate %s symlink: %v", legacyConfigFile, err)
			}
		} else if strings.Contains(f, compressedLayerExt) {
			layerBasename := compat.LayerFilename(counter) + compressedLayerExt
			dstLink := path.Join(*dstDir, layerBasename)
			if err := compat.GenerateSymlinks(f, dstLink); err != nil {
				fmt.Errorf("failed to generate legacy symlink for layer %d at %s: %v", counter, f, err)
			}
			layersDir = append(layersDir, dstLink)
		}
	}

	//TODO: write a manifest.json to dst directory

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

func writeManifest(m v1.Manifest) {

}
