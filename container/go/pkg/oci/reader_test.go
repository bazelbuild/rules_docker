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
// Tests for Read function.
package oci

import (
	"fmt"
	"testing"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/google/go-containerregistry/pkg/v1/validate"
)

// readerTests has test cases for the Read function that loads a docker image stored on disk serialized in OCI format by "Write".
var readertests = []struct {
	// name is the name of this test case.
	name string
	// manifestDigest is the hash code of the manifest metadata file.
	manifestDigest v1.Hash
	// configDigest is the hash code of the config metadata file.
	configDigest v1.Hash
	// layerHashes is an array of hash codes for each layer in this image.
	layerHashes []v1.Hash
	// mediaType is the media type of this image.
	mediaType types.MediaType
	// testPath is the relative path of this test case.
	testPath string
}{
	// This test index ensures the image downloaded by puller.go from gcr.io/asci-toolchain-sandbox/small_img@sha256:4817a495758a70edcaa9ed6723cd927f21c44e2061313b03aaf5d5ae2c1bff46 located in testdata/test_index1 can be loaded.
	{
		"three layer small img(/test_index1)",
		v1.Hash{
			Algorithm: "sha256",
			Hex:       "4817a495758a70edcaa9ed6723cd927f21c44e2061313b03aaf5d5ae2c1bff46",
		},
		v1.Hash{
			Algorithm: "sha256",
			Hex:       "93cd8b73a9da05da6e1a9739e3610cbb0f19439d693931d3bf011d1d92b9e569",
		},
		[]v1.Hash{
			v1.Hash{
				Algorithm: "sha256",
				Hex:       "2cbd3e7a7cca7df9201e626abe080efe75e0588dda3c0188b1caf3a011f300ca",
			},
			v1.Hash{
				Algorithm: "sha256",
				Hex:       "26c668c40574f4fefe17ddfbc3a8744a5b83b8c00a03dff790cbe6a397f66d79",
			},
			v1.Hash{
				Algorithm: "sha256",
				Hex:       "3d4d5ef7eb586de880424d1613e36bc25a1617239ff81d8cf961c6481e6193af",
			},
		},
		types.DockerManifestSchema2,
		"testdata/test_index1",
	},
}

// TestRead checks the v1.Image outputted by <Read> by validating its manifest, layers and configs.
func TestRead(t *testing.T) {
	for _, rt := range readertests {
		t.Run(rt.name, func(t *testing.T) {
			img, err := Read(rt.testPath)
			if err != nil {
				t.Fatalf("Read(%s): %v", rt.testPath, err)
			}

			// Validates that img does not violate any invariants of the image format by validating the layers, manifests and config.
			if err := validate.Image(img); err != nil {
				t.Fatalf("validate.Image(): %v", err)
			}

			mt, err := img.MediaType()
			if err != nil {
				t.Errorf("img.MediaType(): %v", err)
			} else if got, want := mt, rt.mediaType; got != want {
				t.Errorf("img.MediaType(); got: %v want: %v", got, want)
			}

			cfg, err := img.LayerByDigest(rt.configDigest)
			if err != nil {
				t.Errorf("LayerByDigest(%s): %v", rt.configDigest, err)
			}

			cfgName, err := img.ConfigName()
			if err != nil {
				t.Errorf("ConfigName(): %v", err)
			}

			cfgDigest, err := cfg.Digest()
			if err != nil {
				t.Errorf("cfg.Digest(): %v", err)
			}

			if got, want := cfgDigest, cfgName; got != want {
				t.Errorf("ConfigName(); got: %v want: %v", got, want)
			}

			layers, err := img.Layers()
			if err != nil {
				t.Errorf("img.Layers(): %v", err)
			}

			// Validate the digests and media type for each layer.
			for i, layer := range layers {
				if err := validateLayer(layer, rt.layerHashes[i]); err != nil {
					t.Fatalf("layers[%d] is invalid: %v", i, err)
				}
			}

		})
	}
}

// validateLayer checks if the digests and media type matches for the given layer.
func validateLayer(layer v1.Layer, layerHash v1.Hash) error {
	ld, err := layer.Digest()

	if err != nil {
		return err
	}
	if got, want := ld, layerHash; got != want {
		return fmt.Errorf("Digest(); got: %q want: %q", got, want)
	}

	mt, err := layer.MediaType()
	if err != nil {
		return err
	}
	if got, want := mt, types.DockerLayer; got != want {
		return fmt.Errorf("MediaType(); got: %q want: %q", got, want)
	}

	return nil
}

// readerErrorTests has error handling test cases for the Read function.
// Ensures the Read function exits gracefully when given invalid/mismatching path, digest or type.
var readerErrorTests = []struct {
	// name is the name of this test case.
	name string
	// testPath is the relative path of this test case.
	testPath string
}{
	// Tests error handling for a non-existent index path.
	{
		"non-existent testPath",
		"testdata/does_not_exist",
	},
	// Tests error handling for an index missing index.json file.
	{
		"missing index.json",
		"testdata/test_index2",
	},
	// Tests error handling for an index missing manifest metadata file.
	{
		"missing manifest metadata",
		"testdata/test_index3",
	},
	// Tests error handling for an index missing config metadata file.
	{
		"missing config file",
		"testdata/test_index4",
	},
	// Tests error handling for an index missing the specified layer.
	{
		"missing layer",
		"testdata/test_index5",
	},
}

// TestReadErrors checks if each error resulted from readerErrorTests is handled appropriately.
// Tests will fail if Read does not report an error in these cases.
func TestReadErrors(t *testing.T) {
	for _, rt := range readerErrorTests {
		t.Run(rt.name, func(t *testing.T) {
			_, err := Read(rt.testPath)

			if err == nil {
				t.Fatalf("got unexpected success when trying to read an OCI image index, want error")
			}
		})
	}
}
