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
// Tests for Write function.

package oci

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path"
	"strings"
	"testing"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/layout"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/validate"
	"github.com/pkg/errors"
)

var (
	blob     = "blobs/"
	testPath = "testdata/test_write1"
)

var testCases = []struct {
	// name is the name of the test case
	name string
	// dataPath is where the test data is found
	dataPath string
	// the sha code for the manifest
	shaPath string
	// content is the oci layout content where the key is the file path and value is sha256 sum
	content map[string]v1.Hash
}{
	{
		"alpine_linux",
		"testdata/test_write1/small_linux.tar",
		"sha256/9a96f3888ebad00d46bca04ccb591e70d091624835998668af551f48512d9b5c",
		map[string]v1.Hash{
			"blobs/sha256/9a96f3888ebad00d46bca04ccb591e70d091624835998668af551f48512d9b5c": v1.Hash{Algorithm: "sha256", Hex: "9a96f3888ebad00d46bca04ccb591e70d091624835998668af551f48512d9b5c"},
			"index.json": v1.Hash{Algorithm: "sha256", Hex: "ce6ed2e6817add8a5a0e94f4c2ac00360c7ca2cc98c4972b86530f14de622508"},
			"oci-layout": v1.Hash{Algorithm: "sha256", Hex: "b66dbb27a73334db6ac9c030475837bd7f4472d835c72b2360534b203edce6cb"},
		},
	},
}

// TestWrite checks to ensure that the v1.Image written is in OCI format by validating image output format and content
func TestWrite(t *testing.T) {
	for _, wt := range testCases {
		t.Run(wt.name, func(t *testing.T) {
			tmp, err := ioutil.TempDir("", "write-oci-index-test")
			if err != nil {
				t.Errorf("Write(%s): %v", os.TempDir(), err)
			}

			defer os.RemoveAll(tmp)

			img, err := tarball.ImageFromPath(wt.dataPath, nil)
			if err != nil {
				t.Errorf("error loading image from testdata: %v", err)
			}

			if err := Write(img, tmp); err != nil {
				t.Errorf("error writing image to temp path: %v", err)
			}

			if err := assertValidImageOCILayout(tmp, img, wt.content, wt.shaPath); err != nil {
				t.Errorf("image index written is not a valid OCI format: %v", err)
			}
		})
	}
}

// assertValidImageOCILayout checks that the index written is not corrupt
// and that the contents of the OCI layout are all present and non-corrupt
func assertValidImageOCILayout(ociDir string, img v1.Image, content map[string]v1.Hash, shaPth string) error {
	written, err := layout.ImageIndexFromPath(ociDir)
	if err != nil {
		return errors.Wrapf(err, "failed to write image to temp path %s", ociDir)
	}

	if err := validate.Index(written); err != nil {
		return errors.Wrapf(err, "validate.Index() = %v", err)
	}

	// validate that the contents of blobs/ were written in the following format:
	// Top level:
	//     oci-layout, index.json, blobs/
	// Under blobs/, for each image:
	// 	   one file for each layer, config blob, and manifest blob
	for k := range content {
		// validate the files (i.e. index.json, oci-layout)
		if err := validateFile(path.Join(ociDir, k), k, content[k].Hex, ociDir); err != nil {
			return errors.Wrapf(err, "failed to validate %s file", k)
		}
	}

	return nil
}

// compares the SHA256 value of src file to example
func compareSHA(src, want string) error {
	f, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("failed to open file: %v", err)
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return fmt.Errorf("sha256 hashing failed: %v", err)
	}
	got := hex.EncodeToString(h.Sum(nil))
	if strings.Compare(got, want) != 0 {
		return fmt.Errorf("sha256 hex code did not match, wanted: %s got: %s", want, got)
	}

	return nil
}

// validates a file being tested for by checking file is not empty or corrupt
func validateFile(src, file, want, dir string) error {
	f, err := os.Stat(src)
	if err != nil {
		return fmt.Errorf("could not obtain stat: %v", err)
	}

	if os.IsNotExist(err) {
		return fmt.Errorf("wrong OCI output format; got: %v, missing: %s", err, file)
	}
	if f.Size() == 0 {
		return fmt.Errorf("error occured: empty %s, size: %d", file, f.Size())
	}
	if err = compareSHA(path.Join(dir, file), want); err != nil {
		return fmt.Errorf("sha256 hex code did not match, %v", err)
	}

	return nil
}
