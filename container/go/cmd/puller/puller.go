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
	"os"
)

var (
	imgName         = flag.String("name", "", "The name location including repo and digest/tag of the docker image to pull and save. Supports fully-qualified tag or digest references.")
	directory       = flag.String("directory", "", "Where to save the images files.")
	clientConfigDir = flag.String("client-config-dir", "", "Specifies where the custom docker config.json is located. Overiddes the value from DOCKER_CONFIG.")
	cachePath       = flag.String("cache", "", "Image's files cache directory.")
	arch            = flag.String("architecture", "", "Image platform's CPU architecture.")
	os1             = flag.String("os", "linux", "The image's OS, if referring to a multi-platform manifest list. Default linux.")
	osVers          = flag.String("os-version", "", "The image's os version to pull if referring to a multi-platform manifest list.")
	osFeat          = flag.String("os-features", "", "The image's os features when pulling a multi-platform manifest list.")
	variant         = flag.String("variant", "", "The desired CPU variant when image refers to a multi-platform manifest list.")
	features        = flag.String("features", "", "The desired platform features when image refers to a multi-platform manifest list.")
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
		os.Setenv("DOCKER_CONFIG", *clientConfigDir)
	}

	log.Printf("Successfully pulled image %q into %q", *imgName, *directory)
}
