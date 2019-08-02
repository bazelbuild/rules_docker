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
	creationTimeString = flag.String("creationTime", "", "The creation timestamp. Acceptable formats: Integer or floating point seconds since Unix Epoch, RFC 3339 date/time.")
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
	layerDigestFile    arrayFlags
	stampInfoFile      arrayFlags
)

const (
	// createdBy default
	createdBy = "bazel build..."
	// author default
	defaultAuthor = "Bazel"
)

// arrayFlags can be used to store multiple flags the same name.
// the resulting data parsed in will be an array data type.
type arrayFlags []string

func (i *arrayFlags) String() string {
	return fmt.Sprintf("%s", strings.Join(*i, ", "))
}

// Get returns an empty interface that may be type-asserted to the underlying
// value of type bool, string, etc.
func (i *arrayFlags) Get() interface{} {
	return ""
}

func (i *arrayFlags) Set(value string) error {
	*i = append(*i, value)
	return nil
}

// struct Override{

// }

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

	log.Printf("command: %v", command)
	log.Printf("entrypoint: %v", entrypoint)

	log.Println("Running the Image Config manipulator...")

	if *outputConfig == "" {
		log.Fatalln("Required option -outputConfig was not specified.")
	}

	// read config file into struct.
	configFile := &v1.ConfigFile{}
	if *baseConfig != "" {
		// configPath, err := os.Open(*baseConfig)
		configPath, err := ioutil.ReadFile(*baseConfig)

		if err != nil {
			log.Fatalf("Failed to read the base image's config file: %v", err)
		}

		configFile, err = v1.ParseConfigFile(bytes.NewReader(configPath))
		if err != nil {
			log.Fatalf("Failed to successfully parse config file json contents: %v", err)
		}
		// log.Print("Configfile \n")
		// log.Printf("%+v", *configFile)
		// log.Print("end")
	} else {
		// write out an empty config file.
		log.Println("baseConfig is empty!!!")
	}

	// if *nullEntryPoint == "True" {
	// 	entrypoint = []string{}
	// }
	// if *nullCmd == "True" {
	// 	command = []string{}
	// }

	// write out the updated config after overriding config content.
	err := compat.OverrideContent(configFile, *outputConfig, *creationTimeString, *user, *workdir, *nullEntryPoint, *nullCmd, *operatingSystem, createdBy, defaultAuthor, labelsArray[:], ports[:], volumes[:], entrypointPrefix[:], env[:], command[:], entrypoint[:], layerDigestFile[:], stampInfoFile[:])
	if err != nil {
		log.Fatalf("Failed to override values in old image config and write to dst %s: %v", err, *outputConfig)
	}

	log.Printf("Successfully created Image Config at %s.\n", *outputConfig)

	// if *baseManifest != "" {
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

	

	type Q struct{}

	// TODO(xwinxu): write out the updated manifest after updating it from compat pkg.
	// rawManifest, err := json.Marshal(Q{})
	rawManifest, err := json.Marshal(manifestFile)
	if err != nil {
		log.Fatalf("Unable to read config struct into json object: %v", err)
	}
	err = ioutil.WriteFile(*outputManifest, rawManifest, os.ModePerm)
	if err != nil {
		log.Fatalf("Writing config to %s was unsuccessful: %v", *outputManifest, err)
	}

	log.Printf("Successfully created Image Manifest at %s.\n", *outputManifest)
}
