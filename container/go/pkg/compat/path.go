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
// Path used for intermediate image index outputted by python containerregistry. 
// Uses the go-containerregistry API as backend.

package compat

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	v1 "github.com/google/go-containerregistry/pkg/v1"
)

// Path represents an MM intermediate image layout rooted in a file system path
type Path string

// path returns a full directory of this path concatenated with other <elem> paths. 
func (l Path) path(elem ...string) string {
	complete := []string{string(l)}
	return filepath.Join(append(complete, elem...)...)
}

// ImageIndex returns a ImageIndex for the Path.
func (l Path) ImageIndex() (v1.ImageIndex, error) {
	rawManifest, err := ioutil.ReadFile(l.path("manifest.json"))
	if err != nil {
		return nil, err
	}

	idx := &intermediateLayout{
		path:        l,
		rawManifest: rawManifest,
	}

	return idx, nil
}

// Image returns the image with hash <h> in this Path.
func (l Path) Image(h v1.Hash) (v1.Image, error) {
	ii, err := l.ImageIndex()
	if err != nil {
		return nil, err
	}

	return ii.Image(h)
}

// Return the filename for layer at index i in the layers array in manifest.json.
// Assume the layers are padded to three digits, e.g., the first layer is named 000.tar.gz.
func layerFilename(i int) string {
	return fmt.Sprintf("%03d.tar.gz", i)
}
