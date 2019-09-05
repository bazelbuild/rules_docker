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
// Binary flattener generates a tarball of an image's filesystem.
package main

import (
	"flag"
	"io"
	"io/ioutil"
	"log"
	"os"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
)

var (
	imgConfig    = flag.String("config", "", "Path to the image config file.")
	baseManifest = flag.String("manifest", "", "Path to the manifest of the base image. This should be the very first image in the chain of images and is only really required for Windows images with a base image that has foreign layers.")
	imgTarball   = flag.String("tarball", "", "Path to the image tarball.")
	outTarball   = flag.String("filesystem", "", "Path to the output filesystem tarball to generate.")
	outConfig    = flag.String("metadata", "", "Path to the output image config.")
	layers       utils.ArrayStringFlags
)

func main() {
	flag.Var(&layers, "layer", "One or more layers with the following comma separated values (Compressed layer tarball, Uncompressed layer tarball, digest file, diff ID file). e.g., --layer layer.tar.gz,layer.tar,<file with digest>,<file with diffID>.")
	flag.Parse()
	if *outTarball == "" {
		log.Fatalln("Option --filesystem is required.")
	}
	if *outConfig == "" {
		log.Fatalln("Option --metadata is required.")
	}
	if *imgConfig == "" {
		log.Fatalln("Option --config is required.")
	}
	imgParts, err := compat.ImagePartsFromArgs(*imgConfig, *baseManifest, *imgTarball, layers)
	if err != nil {
		log.Fatalf("Unable to determine parts of the image from the specified arguments: %v", err)
	}
	img, err := compat.ReadImage(imgParts)
	if err != nil {
		log.Fatalf("Error reading image: %v", err)
	}
	c, err := img.RawConfigFile()
	if err != nil {
		log.Fatalf("Unable to get config from image: %v", err)
	}
	if err := ioutil.WriteFile(*outConfig, c, os.ModePerm); err != nil {
		log.Fatalf("Unable to write image config to %s: %v", *outConfig, err)
	}
	o := mutate.Extract(img)
	f, err := os.Create(*outTarball)
	if err != nil {
		log.Fatalf("Unable to create output flattened tarball file %s: %v", *outTarball, err)
	}
	if _, err := io.Copy(f, o); err != nil {
		log.Fatalf("Unable to write to output flattened tarball file %s: %v", *outTarball, err)
	}
}
