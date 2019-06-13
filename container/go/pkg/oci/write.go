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
// This binary writes images into a tarball format.
// Disclaimer: we will change the package name from tarball to a more efficient format once it is implemented in the future.

package oci

import (
	"fmt"
	"log"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/layout"
)

// Write writes a v1.Image to the Path and updates the index.json to reference it.
// This is just syntactic sugar wrapping Path.AppendImage from the go-container registry.
func Write(img v1.Image, dstPath string) error {
	// Path represents an OCI image layout ooted in a file system path
	var path layout.Path
	var err error

	// Open the layout, if it already exists.
	if path, err = layout.FromPath(dstPath); err != nil {
		// Does not already exist, so initialize it with an empty index.
		if path, err = layout.Write(dstPath, empty.Index); err != nil {
			log.Fatalf("cannot initialize layout: %v", err)
		}

	}

	if err := path.AppendImage(img); err != nil {
		return fmt.Errorf("unable to write image to path")
	}
	return nil
}
