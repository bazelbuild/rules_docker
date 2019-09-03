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
//This binary implements the ability to load a docker image tarball and
// extract its config & manifest json to paths specified via command line
// arguments.
// It expects to be run with:
//     extract_config -tarball=image.tar -output=output.confi
package main

import (
	"flag"
	"io/ioutil"
	"log"

	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

var (
	imageTar       = flag.String("imageTar", "", "The path to the Docker image tarball to extract the config & manifest for.")
	outputConfig   = flag.String("outputConfig", "", "The path to the output file where the image config will be written to.")
	outputManifest = flag.String("outputManifest", "", "The path to the output file where the image manifest will be written to.")
)

func main() {
	flag.Parse()
	if *imageTar == "" {
		log.Fatalln("Required option -imageTar was not specified.")
	}
	if *outputConfig == "" {
		log.Fatalln("Required option -outputConfig was not specified.")
	}
	if *outputManifest == "" {
		log.Fatalln("Required option -outputManifest was not specified.")
	}

	img, err := tarball.ImageFromPath(*imageTar, nil)
	if err != nil {
		log.Fatalf("Unable to load docker image from %s: %v", *imageTar, err)
	}

	// Write the config file contents to the ouput file specified withh permissions 0644.
	configContent, err := img.RawConfigFile()
	if err != nil {
		log.Fatalf("Failed to read config file: %v", err)
	}
	if err := ioutil.WriteFile(*outputConfig, configContent, 0644); err != nil {
		log.Fatalf("Failed to write config file contents to %s: %v", *outputConfig, err)
	}

	// Write the manifest file contents to the manifestoutput file specified with permissions 0644.
	manifestContent, err := img.RawManifest()
	if err != nil {
		log.Fatalf("Failed to read manifest file: %v", err)
	}
	if err := ioutil.WriteFile(*outputManifest, manifestContent, 0644); err != nil {
		log.Fatalf("Failed to write manifest file contents to %s: %v", *outputManifest, err)
	}
}
