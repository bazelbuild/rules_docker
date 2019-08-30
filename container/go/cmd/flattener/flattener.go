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

	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
)

var (
	// The argument names match the arguments of https://github.com/google/containerregistry/blob/master/tools/fast_flatten_.py
	// for backwards compatibility. Many of these arguments are not actually used
	// but they are defined to make the Go flattener a drop-in replacement for the
	// python flattener.
	imgConfig  = flag.String("config", "", "Path to the image config file.")
	imgTarball = flag.String("tarball", "", "Path to the image tarball.")
	outTarball = flag.String("filesystem", "", "Path to the output filesystem tarball to generate.")
	outConfig  = flag.String("metadata", "", "Path to the output image config.")
	layers     utils.ArrayStringFlags
)

func main() {
	flag.Var(&layers, "layer", "One or more layers with the following comma separated values (Compressed layer tarball, Uncompressed layer tarball, digest file, diff ID file). e.g., --layer layer1.tar.gz,layer1.tar,<file with digest>,<file with diffID>.")
	flag.Parse()
	if *outTarball == "" {
		log.Fatalln("Option --filesystem is required.")
	}
	if *outConfig == "" {
		log.Fatalln("Option --metadata is required.")
	}
	if *imgTarball == "" && len(layers) == 0 {
		log.Fatalln("Either --tarball or --layer must be specified for the input image. Neither was specified.")
	}
	if *imgTarball != "" && len(layers) > 0 {
		log.Fatalf("Both --tarball=%q and --layer=%v were specified. Exactly one of these options must be specified.", *imgTarball, layers)
	}
	if len(layers) > 0 && *imgConfig == "" {
		log.Fatalln("--config is required because one or more --layer was specified.")
	}
	imgParts, err := utils.ImagePartsFromArgs(*imgConfig, layers)
	if err != nil {
		log.Fatalf("Unable to determine parts of the image from --config=%s & --layer=%v: %v", *imgConfig, layers, err)
	}
	img, err := utils.ReadImage(*imgTarball, imgParts)
	if err != nil {
		log.Fatalf("Failed to load image: %v", err)
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
