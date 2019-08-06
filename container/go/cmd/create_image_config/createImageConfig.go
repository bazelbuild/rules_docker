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
// It writes out both a config file and a manifest for the v2.2 image.

package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"io/ioutil"
	"log"
	"os"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
	v1 "github.com/google/go-containerregistry/pkg/v1"
)

var (
	baseConfig         = flag.String("baseConfig", "", "The base image config.")
	baseManifest       = flag.String("baseManifest", "", "The base image manifest.")
	outputConfig       = flag.String("outputConfig", "", "The output image config file to generate.")
	outputManifest     = flag.String("outputManifest", "", "The output manifest file to generate.")
	creationTimeString = flag.String("creationTime", "", "The creation timestamp. Acceptable formats: Integer or floating point seconds since Unix Epoch, RFC 3339 date/time.")
	user               = flag.String("user", "", "The username to run the commands under.")
	workdir            = flag.String("workdir", "", "Set the working directory of the layer.")
	nullEntryPoint     = flag.String("nullEntryPoint", "False", "If True, Entrypoint will be set to null.")
	nullCmd            = flag.String("nullCmd", "False", "If True, Cmd will be set to null.")
	operatingSystem    = flag.String("operatingSystem", "linux", "Operating system to create docker image for, eg. linux.")
	labelsArray        utils.ArrayStringFlags
	ports              utils.ArrayStringFlags
	volumes            utils.ArrayStringFlags
	entrypointPrefix   utils.ArrayStringFlags
	env                utils.ArrayStringFlags
	command            utils.ArrayStringFlags
	entrypoint         utils.ArrayStringFlags
	layerDigestFile    utils.ArrayStringFlags
	stampInfoFile      utils.ArrayStringFlags
)

const (
	// createdBy default
	createdBy = "bazel build..."
	// author default
	defaultAuthor = "Bazel"
)

func main() {
	log.Println("Args before:", os.Args)
	flag.Var(&labelsArray, "labels", "Augment the Label of the previous layer.")
	flag.Var(&ports, "ports", "Augment the ExposedPorts of the previous layer.")
	flag.Var(&volumes, "volumes", "Augment the Volumes of the previous layer.")
	flag.Var(&entrypointPrefix, "entrypointPrefix", "Prefix the Entrypoint with the specified arguments.")
	flag.Var(&env, "env", "Augment the Env of the previous layer.")
	flag.Var(&command, "command", "Override the Cmd of the previous layer.")
	flag.Var(&entrypoint, "entrypoint", "Override the Entrypoint of the previous layer.")
	flag.Var(&layerDigestFile, "layerDigestFile", "Layer sha256 hashes that make up this image. The order that these layers are specified matters.")
	flag.Var(&stampInfoFile, "stampInfoFile", "A list of files from which to read substitutions to make in the provided fields.")

	flag.Parse()

	log.Println("Running the Image Config creator...")

	if *outputConfig == "" {
		log.Fatalln("Required option -outputConfig was not specified.")
	}

	configFile := &v1.ConfigFile{}
	if *baseConfig != "" {
		configPath, err := ioutil.ReadFile(*baseConfig)
		if err != nil {
			log.Fatalf("Failed to read the base image's config file: %v", err)
		}

		configFile, err = v1.ParseConfigFile(bytes.NewReader(configPath))
		if err != nil {
			log.Fatalf("Failed to successfully parse config file json contents: %v", err)
		}
	} else {
		// write out an empty config file.
		log.Println("baseConfig is empty!")
	}

	overrideConfig := compat.OverrideConfigOpts{
		ConfigFile:         configFile,
		OutputConfig:       *outputConfig,
		CreationTimeString: *creationTimeString,
		User:               *user,
		Workdir:            *workdir,
		NullEntryPoint:     *nullEntryPoint,
		NullCmd:            *nullCmd,
		OperatingSystem:    *operatingSystem,
		CreatedByArg:       createdBy,
		AuthorArg:          defaultAuthor,
		LabelsArray:        labelsArray[:],
		Ports:              ports[:],
		Volumes:            volumes[:],
		EntrypointPrefix:   entrypointPrefix[:],
		Env:                env[:],
		Command:            command[:],
		Entrypoint:         entrypoint[:],
		Layer:              layerDigestFile[:],
		StampInfoFile:      stampInfoFile[:],
	}

	// write out the updated config after overriding config content.
	err := compat.OverrideImageConfig(&overrideConfig)
	if err != nil {
		log.Fatalf("Failed to override values in old image config and write to dst %s: %v", err, *outputConfig)
	}

	log.Printf("Successfully created Image Config at %s.\n", *outputConfig)

	// Q is an empty struct for writing empty manifest if applicable.
	type Q struct{}

	log.Println("Running the Image Manifest creator...")

	if *baseManifest != "" {
		log.Printf(*baseManifest)
		manifest, err := ioutil.ReadFile(*baseManifest)

		err = ioutil.WriteFile(*outputManifest, manifest, os.ModePerm)
		if err != nil {
			log.Fatalf("Writing config to %s was unsuccessful: %v", *outputManifest, err)
		}
	} else {
		rawManifest, err := json.Marshal(Q{})
		if err != nil {
			log.Fatalf("Unable to read manifest struct into json object: %v", err)
		}
		err = ioutil.WriteFile(*outputManifest, rawManifest, os.ModePerm)
		if err != nil {
			log.Fatalf("Writing config to %s was unsuccessful: %v", *outputManifest, err)
		}
	}

	log.Printf("Successfully created Image Manifest at %s.\n", *outputManifest)
}
