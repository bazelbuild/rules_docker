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
/////////////////////////////////////////////////////////////////////
// This rule imports an image from a `docker save` tarball using the go_containerregistry.
//
// Extracts the tarball, examines the layers, and creates a container_import
// target for use with container_image

package main

import (
	"flag"
	"io"
	"log"
	"os"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/pkg/errors"
)

var (
	outDir     = flag.String("directory", "", "Where to save the image's files.")
	imgTarball = flag.String("tarball", "", "The path to the tarball to load.")
)

func opener() tarball.Opener {
	isGzip, err := isGzip(*imgTarball)
	if err != nil {
		log.Fatalf("Failed to determine if tarball is gzip compressed: %v", err)
	}
	if isGzip {
		return func() (io.ReadCloser, error) {
			return newGZReadCloser(*imgTarball)
		}
	} else {
		return func() (io.ReadCloser, error) {
			return os.Open(*imgTarball)
		}
	}
}

// load loads a docker image tarball generated by docker save from path <dir>.
func load(tar, dir string) error {
	img, err := tarball.Image(opener(), nil)
	if err != nil {
		return errors.Wrapf(err, "failed to read docker image tarball from %q", dir)
	}

	if err := compat.WriteImage(img, dir); err != nil {
		return errors.Wrapf(err, "unable to extract image parts from tarball %s", tar)
	}

	return nil
}

func main() {
	flag.Parse()
	log.Println("Running the Image Loader to load the image tarball...")

	if *outDir == "" {
		log.Fatalln("Required option -directory was not specified.")
	}
	if *imgTarball == "" {
		log.Fatalln("Required option -tarball was not specified.")
	}

	if err := load(*imgTarball, *outDir); err != nil {
		log.Fatalf("Failed to load tarball into OCI format: %v", err)
	}

	log.Printf("Successfully wrote docker image tarball to %q", *outDir)
}
