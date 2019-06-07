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
// This binary pulls images from a Docker Registry.
// Unlike regular docker pull, the format this package uses is proprietary.

package main

import (
	"flag"
	"log"
	ospkg "os"
)

var (
	imgName         = flag.String("name", "", "The name location including repo and digest/tag of the docker image to pull and save. Supports fully-qualified tag or digest references.")
	directory       = flag.String("directory", "", "Where to save the images files.")
	clientConfigDir = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	cachePath       = flag.String("cache", "", "Image's files cache directory.")
	arch            = flag.String("architecture", "", "Image platform's CPU architecture.")
	os              = flag.String("os", "", "Image's operating system, if referring to a multi-platform manifest list. Default linux.")
	osVersion       = flag.String("os-version", "", "Image's operating system version, if referring to a multi-platform manifest list.")
	osFeatures      = flag.String("os-features", "", "Image's operating system features, if referring to a multi-platform manifest list.")
	variant         = flag.String("variant", "", "Image's CPU variant, if referring to a multi-platform manifest list.")
	features        = flag.String("features", "", "Image's CPU features, if referring to a multi-platform manifest list.")
)

func main() {
	flag.Parse()
	log.Println("Running the Image Puller to pull images from a Docker Registry...")

	if *imgName == "" {
		log.Fatalln("Required option -name was not specified.")
	}
	if *directory == "" {
		log.Fatalln("Required option -directory was not specified.")
	}

	// If the user provided a client config directory, instruct the keychain resolver
	// to use it to look for the docker client config
	if *clientConfigDir != "" {
		ospkg.Setenv("DOCKER_CONFIG", *clientConfigDir)
	}
	log.Fatalf("here")

	log.Printf("Successfully pulled image %q into %q", *imgName, *directory)
}
