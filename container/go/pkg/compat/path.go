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
	"fmt"
	"os"
	"path/filepath"
)

// Expected metadata files in legacy layout.
const (
	manifestFile = "manifest.json"
	configFile   = "config.json"
	digestFile   = "digest"
)

// Return the filename for layer at index i in the layers array in manifest.json.
// Assume the layers are padded to three digits, e.g., the first layer is named 000.tar.gz.
func LayerFilename(i int) string {
	return fmt.Sprintf("%01d.tar.gz", i)
}

// Naively validates a legacy intermediate layout at <path> by checking if digest, config.json, and manifest.json all exist.
func isValidLegacylayout(path string) (bool, error) {
	if _, err := os.Stat(filepath.Join(path, manifestFile)); err != nil {
		return false, err
	}

	if _, err := os.Stat(filepath.Join(path, configFile)); err != nil {
		return false, err
	}

	if _, err := os.Stat(filepath.Join(path, digestFile)); err != nil {
		return false, err
	}

	return true, nil
}
