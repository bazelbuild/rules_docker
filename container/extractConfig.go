// Copyright 2017 The Bazel Authors. All rights reserved.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//    http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//////////////////////////////////////////////////
// A Go binary to extract the v2.2 config file from a Docker image tarball.

package main

import (
	"io/ioutil"
	"log"
	"flag"
	tarpkg "github.com/google/go-containerregistry/pkg/v1/tarball"
)

var (
	tarball = flag.String("tarball", "", "The Docker image tarball from which to extract the image name.")
	output = flag.String("output", "", "The output file to which we write the config.")
	manifestOutput = flag.String("manifestoutput", "", "The output file to which we write the manifest.")
)

// main creates a docker image. It expects to be run with:
//   extract_config -tarball=image.tar -output=output.config
func main() {
	flag.Parse()
	log.Println("Extracting the config file from the tarball...")

	img, err := tarpkg.ImageFromPath(*tarball, nil)
	if err != nil {
		log.Fatalf("Extracting config file failed: %v", err)
	}

	// Write the config file contents to the ouput file specified withh permissions 0644.
	configContent, err := img.RawConfigFile()
	if err != nil {
		log.Fatalf("Failed to read config file: %v", err)
	}
	if err := ioutil.WriteFile(*output, configContent, 0644); err != nil {
		log.Fatalf("Failed to write config file contents to %s: %v", *output, err)
	}

	// Write the manifest file contents to the manifestoutput file specified with permissions 0644.
	manifestContent, err := img.RawManifest()
	if err != nil {
		log.Fatalf("Failed to read manifest file: %v", err)
	}
	if err := ioutil.WriteFile(*manifestOutput, manifestContent, 0644); err != nil {
		log.Fatalf("Failed to write manifest file contents to %s: %v", *manifestOutput, err)
	}

	log.Println("Successfully extracted config file from tarball")
}