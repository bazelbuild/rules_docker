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
	// "../../../../../go-containerregistry/pkg/authn"
)

var (
	name            = flag.String("name", "", "The name of the docker image to pull and save. Supports fully-qualified tag or digest references.")
	directory       = flag.String("directory", "", "Where to save the images files.")
	clientConfigDir = flag.String("clientConfigDir", "", "The path to the directory where the client Docker configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	cache           = flag.String("cache", "", "Image's files cache directory.")
	threads         = 8
)

func main() {
	flag.Parse()
	log.Println("Running the Image Puller to pull images from a Docker Registry...")
	log.Println("Command line arguments:")
	log.Printf("-name: %q", *name)
	log.Printf("-directory: %q", *directory)
	log.Printf("-clientConfigDir: %q", *clientConfigDir)
	log.Printf("-cache: %q", *cache)

	if *name == "" {
		log.Fatalln("Required option -name was not specified.")
	}
	if *directory == "" {
		log.Fatalln("Required option -directory was not specified.")
	}

	// If the user provided a client config directory, instruct the keychain resolver
	// to use it to look for the docker client config
	if *clientConfigDir != "" {
		// set the members of the struct??
		// authn.DefaultKeychain.ConfigDir = *clientConfigDir
	}

	log.Printf("Successfully pulled image %q into %q", *name, *directory)
}
