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
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	v1 "github.com/google/go-containerregistry/pkg/v1"
)

var (
	baseConfig         = flag.String("baseConfig", "", "The base image config.")
	baseManifest       = flag.String("baseManifest", "", "The base image manifest.")
	outputConfig       = flag.String("outputConfig", "", "The output image config file to generate.")
	outputManifest     = flag.String("outputManifest", "", "The output manifest file to generate.")
	creationTimeString = flag.String("creationTime", "", "The creation timestamp. Acceptable formats: Integer or floating point seconds since Unix Epoch, RFC, 3339 date/time.")
	user               = flag.String("user", "", "The username to run the commands under.")
	workdir            = flag.String("workdir", "", "Set the working directory of the layer.")
	nullEntryPoint     = flag.String("nullEntryPoint", "False", "If True, Entrypoint will be set to null.")
	nullCmd            = flag.String("nullCmd", "False", "If True, Cmd will be set to null.")
	operatingSystem    = flag.String("operatingSystem", "linux", "Operating system to create docker image for, eg. linux.")
	labelsArray        arrayFlags
	ports              arrayFlags
	volumes            arrayFlags
	entrypointPrefix   arrayFlags
	env                arrayFlags
	command            arrayFlags
	entrypoint         arrayFlags
	layerDigest        arrayFlags
	stampInfoFile      arrayFlags
)

const (
	// defaultProcArch is the default architecture type based on legacy create_image_config.py.
	defaultProcArch = "amd64"
	// defaultTimeStamp is the unix epoch 0 time representation in 32 bits.
	defaultTimestamp = "1970-01-01T00:00:00Z"
)

// arrayFlags can be used to store multiple flags the same name.
// the resulting data parsed in will be an array data type.
type arrayFlags []string

func (i *arrayFlags) String() string {
	return fmt.Sprintf("%s", strings.Join(*i, ", "))
}

func (i *arrayFlags) Set(value string) error {
	*i = append(*i, value)
	return nil
}

func main() {
	flag.Var(&labelsArray, "labels", "Augment the Label of the previous layer.")
	flag.Var(&ports, "ports", "Augment the ExposedPorts of the previous layer.")
	flag.Var(&volumes, "volumes", "Augment the Volumes of the previous layer.")
	flag.Var(&entrypointPrefix, "entrypointPrefix", "Prefix the Entrypoint with the specified arguments.")
	flag.Var(&env, "env", "Augment the Env of the previous layer.")
	flag.Var(&command, "command", "Override the Cmd of the previous layer.")
	flag.Var(&entrypoint, "entrypoint", "Override the Entrypoint of the previous layer.")
	flag.Var(&layerDigest, "layer", "Layer sha256 hashes that make up this image. The order that these layers are specified matters.")
	flag.Var(&stampInfoFile, "stampInfoFile", "A list of files from which to read substitutions to make in the provided fields.")
	flag.Parse()
	log.Println("Running the Image Config manipulator...")

	if *outputConfig == "" {
		log.Fatalln("Required option -outputConfig was not specified.")
	}
	if *nullEntryPoint == "True" {
		entrypoint = nil
	}
	if *nullCmd == "True" {
		command = nil
	}

	// read config file into struct.
	configPath, err := os.Open(*baseConfig)
	if err != nil {
		log.Fatalf("Failed to read the base image's config file: %v", err)
	}
	configFile, err := v1.ParseConfigFile(configPath)
	if err != nil {
		log.Fatalf("Failed to successfully parse config file json contents: %v", err)
	}

	// write out the updated config after overriding
	err = compat.OverrideContent(configFile, *outputConfig, *creationTimeString, *user, *workdir, *nullEntryPoint, *nullCmd, *operatingSystem, labelsArray[:], ports[:], volumes[:], entrypointPrefix[:], env[:], command[:], entrypoint[:], layerDigest[:], stampInfoFile[:])
	if err != nil {
		log.Fatalf("Failed to override values in old image config and write to dst %s: %v", err, *outputConfig)
	}

	log.Printf("Successfully created Image Config at %s.\n", *outputConfig)

	// read manifest file into struct if provided.
	manifestFile := v1.Manifest{}
	if *baseManifest != "" {
		manifestPath, err := ioutil.ReadFile(*baseManifest)
		if err != nil {
			log.Fatalf("Failed to read the base image's manifest: %v", err)
		}
		if err = json.Unmarshal([]byte(manifestPath), &manifestFile); err != nil {
			log.Fatalf("Failed to successfully read manifest file contents: %v", err)
		}
	}

	// TODO(xwinxu): write out the updated manifest after updating it from compat pkg.
	rawManifest, err := json.Marshal(manifestFile)
	if err != nil {
		log.Fatalf("Unable to read config struct into json object: %v", err)
	}
	err = ioutil.WriteFile(*outputManifest, rawManifest, os.ModePerm)
	if err != nil {
		log.Fatalf("Writing config to %s was unsuccessful: %v", *outputManifest, err)
	}

	log.Println("Successfully created Image Manifest at %s.\n", *outputManifest)
}
