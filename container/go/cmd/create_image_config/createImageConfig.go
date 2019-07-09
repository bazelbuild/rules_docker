// Copyright 2016 The Bazel Authors. All rights reserved.
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
////////////////////////////////////////////////
// This package manipulates v2.2 image configuration metadata.

package main

import (
	"flag"
	"log"
	// "log"
	// "github.com/google/go-containerregistry/pkg/v1/mutate"
)

var (
	base             = flag.String("base", "", "The parent image.")
	baseManifest     = flag.String("baseManifest", "", "The parent image manifest.")
	output           = flag.String("output", "", "The output file to generate.")
	outputManifest   = flag.String("outputManifest", "", "The manifest output file to generate.")
	layer            = flag.String("layer", "[]", "Layer sha256 hashes that make up this image.")
	entrypoint       = flag.String("entrypoint", "[]", "Override the Entrypoint of the previous layer.")
	command          = flag.String("command", "[]", "Override the Cmd of the previous layer.")
	creationTime     = flag.String("creationTime", "", "The creation timestamp. Acceptable formats: Integer or floating point seconds since Unix Epoch, RFC, 3339 date/time.")
	user             = flag.String("user", "", "The username to run the commands under.")
	labels           = flag.String("labels", "[]", "Augement the Label of the previous layer.")
	ports            = flag.String("ports", "[]", "Augment the ExposedPorts of the previous layer.")
	volumes          = flag.String("volumes", "[]", "Augment the Volumes of the previous layer.")
	workdir          = flag.String("workdir", "", "Set the working directory of the layer.")
	env              = flag.String("env", "[]", "Augment the Env of the previous layer.")
	stampInfoFile    = flag.String("stampInfoFile", "", "A list of files from which to read substitutions to make in the provided fields.")
	nullEntryPoint   = flag.String("nullEntryPoint", "False", "If True, Entrypoint will be set to null.")
	nullCmd          = flag.String("nullCmd", "False", "If True, Cmd will be set to null.")
	operatingSystem  = flag.String("operatingSystem", "linux", "Operating system to create docker image for distro specified.")
	entrypointPrefix = flag.String("entrypointPrefix", "[]", "Prefix the Entrypoint with the specified arguments.")
)

func main() {
	flag.Parse()
	log.Println("Running the Image Config manipulator...")

	if *output == "" {
		log.Fatalln("Required option -output was not specified.")
	}
	if *nullEntryPoint == "True" {
		entrypoint = nil
	}
	if *nullCmd == "True" {
		command = nil
	}

	log.Println("Successfully created Image Config.")
}
