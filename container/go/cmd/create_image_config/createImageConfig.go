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
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"strings"
	"text/template"
	"time"

	"github.com/pkg/errors"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	// "github.com/google/go-containerregistry/pkg/v1/mutate"
)

var (
	baseConfig       = flag.String("baseConfig", "", "The parent image.")
	baseManifest     = flag.String("baseManifest", "", "The parent image manifest.")
	outputConfig     = flag.String("outputConfig", "", "The output file to generate.")
	outputManifest   = flag.String("outputManifest", "", "The manifest output file to generate.")
	creationTime     = flag.String("creationTime", "", "The creation timestamp. Acceptable formats: Integer or floating point seconds since Unix Epoch, RFC, 3339 date/time.")
	user             = flag.String("user", "", "The username to run the commands under.")
	workdir          = flag.String("workdir", "", "Set the working directory of the layer.")
	nullEntryPoint   = flag.String("nullEntryPoint", "False", "If True, Entrypoint will be set to null.")
	nullCmd          = flag.String("nullCmd", "False", "If True, Cmd will be set to null.")
	operatingSystem  = flag.String("operatingSystem", "linux", "Operating system to create docker image for distro specified.")
	labelsArray      arrayFlags
	ports            arrayFlags
	volumes          arrayFlags
	entrypointPrefix arrayFlags
	env              arrayFlags
	command          arrayFlags
	entrypoint       arrayFlags
	layer            arrayFlags
	stampInfoFile    arrayFlags
)

// default architecture type based on legacy create_image_config.py
const processorArchitecture = "amd64"

// empty file sha256 sum
const emptyFile = sha256.Sum256([]byte(""))

// unix epoch 0, representation in 32 bits
const defaultTimestamp = "1970-01-01T00:00:00Z"

// arrayFlags is a type that can handle multiple flags of the same name.
// the resulting data parsed in will be an array data type.
type arrayFlags []string

func (i *arrayFlags) String() string {
	return fmt.Sprintf("%s", strings.Join(*i, ", "))
}

func (i *arrayFlags) Set(value string) error {
	*i = append(*i, value)
	return nil
}

// extractValue returns the contents of a file pointed to by value if it starts with a '@'.
func extractValue(value string) (string, error) {
	if strings.HasPrefix(value, "@") {
		f, err := os.Open(value[1:])
		if err != nil {
			return "", errors.Wrapf(err, "failed to open file at %s", value[1:])
		}
		defer f.Close()
		shaHash, err := ioutil.ReadAll(f)
		if err != nil {
			return "", errors.Wrapf(err, "failed to read content from file %s", value[1:])
		}
		return string(shaHash), nil
	}
	return value, errors.Wrapf(nil, "unexpected value, got: %s want: @{...}", value)
}

// keyValueToMap converts an array of strings separated by '=' into a map of key-value pairs.
// if toFormat is set to True, adds a . in front of the value so that the string can be formatted.
func keyValueToMap(value []string) map[string]string {
	convMap := make(map[string]string)
	var temp []string
	for _, kvpair := range value {
		temp = strings.Split(kvpair, "=")
		key, val := temp[0], temp[1]
		convMap[key] = val
	}
	return convMap
}

type formattedString map[string]interface{}

func formatWithMap(format string, params formattedString) string {
	msg := &bytes.Buffer{}
	template.Must(template.New("").Parse(format)).Execute(msg, params)
	return msg.String()
}

// stamp provides the substitutions of variables inside {} using info in file pointed to
// by stampInfoFile.
func stamp(inp string) (string, error) {
	if len(stampInfoFile) == 0 || inp == "" {
		return inp, nil
	}
	formatArgs := make(map[string]interface{})
	for _, infofile := range stampInfoFile {
		f, err := os.Open(infofile)
		if err != nil {
			return "", errors.Wrapf(err, "failed to open file %s", infofile)
		}
		defer f.Close()
		// scanner reads line by line and discards '\n' character already
		scanner := bufio.NewScanner(f)
		var temp []string
		for scanner.Scan() {
			temp = strings.Split(scanner.Text(), " ")
			key, val := temp[0], temp[1]
			if _, ok := formatArgs[key]; ok {
				fmt.Printf("WARNING: Duplicate value for key %s: using %s", key, val)
			}
			formatArgs[key] = val
		}
		if err = scanner.Err(); err != nil {
			return "", errors.Wrapf(err, "failed to read line from file %s", infofile)
		}
	}
	// do string manipulation in order to mimic python string format.
	// specifically, replace '{' with '{{.' and '}' with '}}'.
	inpReformatted := strings.ReplaceAll(inp, "{", "{{.")
	inpReformatted = strings.ReplaceAll(inpReformatted, "}", "}}")
	return formatWithMap(inpReformatted, formattedString(formatArgs)), nil
}

// mapToKeyValue reverses a map to a '='-separated array of strings in {key}={value} format
func mapToKeyValue(kvMap map[string]string) []string {
	keyVals := []string{}
	concatenated := ""
	for k, v := range kvMap {
		concatenated = k + "=" + v
		keyVals = append(keyVals, concatenated)
	}
	return keyVals
}

// resolveVariables resolves the environment variables embedded in the given value using
// provided map of environment variable expansions.
// It handles formats like "PATH=$PATH:..."
func resolveVariables(value string, environment map[string]string) (string, error) {
	var i interface{}
	i = "this is a string type"
	var errorMet = false
	mapper := func(p string) string {
		switch i.(type) {
		case string:
			return environment[p]
		}
		errorMet = true
		return ""
	}
	if errorMet {
		err := errors.New("environment variable sought after does not exist in evnrionemnet map")
		if err != nil {
			errors.Wrap(err, "failed to create new error")
		}
		return "", err
	}
	return os.Expand(value, mapper), nil
}

func main() {
	flag.Var(&labelsArray, "labels", "Augment the Label of the previous layer.")
	flag.Var(&ports, "ports", "Augment the ExposedPorts of the previous layer.")
	flag.Var(&volumes, "volumes", "Augment the Volumes of the previous layer.")
	flag.Var(&entrypointPrefix, "entrypointPrefix", "Prefix the Entrypoint with the specified arguments.")
	flag.Var(&env, "env", "Augment the Env of the previous layer.")
	flag.Var(&command, "command", "Override the Cmd of the previous layer.")
	flag.Var(&entrypoint, "entrypoint", "Override the Entrypoint of the previous layer.")
	flag.Var(&layer, "layer", "Layer sha256 hashes that make up this image.")
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
	configPath, err := ioutil.ReadFile(*baseConfig)
	if err != nil {
		log.Fatalf("Failed to read the parent image's config file: %v", err)
	}
	configFile := v1.ConfigFile{}
	if err = json.Unmarshal([]byte(configPath), &configFile); err != nil {
		log.Fatalf("Failed to successfully read config file contents: %v", err)
	}

	// read manifest file into struct if provided.
	if *baseManifest != "" {
		manifestPath, err := ioutil.ReadFile(*baseManifest)
		if err != nil {
			log.Fatalf("Failed to read the parent image's manifest: %v", err)
		}
		manifestFile := v1.Manifest{}
		if err = json.Unmarshal([]byte(manifestPath), &manifestFile); err != nil {
			log.Fatalf("Failed to successfully read manifest file contents: %v", err)
		}
	}

	var createTime string
	var unixTime int64
	if *creationTime == "" {
		creationTime = nil
	} else {
		if createTime, err = stamp(*creationTime); err != nil {
			log.Fatalf("Unable to format creation time from BUILD_TIMESTAMP macros: %v", err)
		}
		// if creationTime is parsable as a floating point type, assume unix epoch timestamp.
		// otherwise, assume RFC 3339 date/time format.
		unixTime, err := strconv.ParseInt(createTime, 10, 64)
		if err != nil {
			log.Fatalf("Unable to parse a floating point type from flag creationTime: %v", err)
		} else {
			if unixTime > 1.0e+11 {
				unixTime = unixTime / 1000.0
			}
			// construct a RFC 3339 date/time from Unix epoch.
			t := time.Unix(unixTime, 0)
			creationTime := t.Format(time.RFC3339)
		}
	}

	configFile.Author = "Bazel"
	configFile.OS = *operatingSystem
	configFile.Architecture = processorArchitecture

	// output['config'] = defaults.get('config', {}) line 161
	configFile.Config = v1.Config{}
	if len(entrypoint) > 0 {
		configFile.Config.Entrypoint = entrypoint
	}
	if len(command) > 0 {
		configFile.Config.Cmd = command
	}
	if *user != "" {
		configFile.Config.User = *user
	}

	if len(env) != 0 {
		environMap := keyValueToMap(env)
		var resolvedValue string
		for k, v := range environMap {
			if resolvedValue, err = resolveVariables(v, environMap); err != nil {
				log.Fatalf("Unable to resolve environment variables from path %s: %v", v, err)
			}
			environMap[k] = resolvedValue
		}
		configFile.Config.Env = mapToKeyValue(environMap)
	}

	labels := keyValueToMap(labelsArray)
	for label, value := range labels {
		if strings.HasPrefix(value, "@") {
			if labels[label], err = extractValue(value); err != nil {
				log.Fatalf("Failed to extract the contents of labels file: %v", err)
			}
		} else if strings.Contains(value, "{") {
			if labels[label], err = stamp(value); err != nil {
				log.Fatalf("Failed to format the string accordingly at %s: %v", value, err)
			}
		}
	}
	if len(labelsArray) > 0 {
		labelsMap := make(map[string]string)
		for k, v := range labels {
			labelsMap[k] = v
		}
		configFile.Config.Labels = labelsMap
	}

	if len(ports) > 0 {
		if len(configFile.Config.ExposedPorts) == 0 {
			configFile.Config.ExposedPorts = make(map[string]struct{})
		}
		for _, port := range ports {
			if strings.Contains(port, "/") {
				// the port spec has the form 80/tcp, 1234/udp so simply use it as the key.
				configFile.Config.ExposedPorts[port] = struct{}{}
			} else {
				// assume tcp
				configFile.Config.ExposedPorts[port+"/tcp"] = struct{}{}
			}
		}
	}

	if len(volumes) > 0 {
		if len(configFile.Config.Volumes) == 0 {
			configFile.Config.Volumes = make(map[string]struct{})
		}
		for _, volume := range volumes {
			configFile.Config.Volumes[volume] = struct{}{}
		}
	}

	if *workdir != "" {
		configFile.Config.WorkingDir = *workdir
	}

	layers := []string{}
	for _, l := range layer {
		newLayer, err := extractValue(l)
		if err != nil {
			log.Fatalf("Failed to extract the contents of layer file: %v", err)
		}
		layers = append(layers, newLayer)
	}
	// diffIDs are ordered from bottom-most to top-most
	// []Hash type
	diffIDs := configFile.RootFS.DiffIDs
	if len(layer) > 0 {
		var diffIDToAdd v1.Hash
		for _, layer := range layers {
			if layer != emptyFile {
				diffIDToAdd = v1.Hash{Algorithm: "sha256", Hex: layer}
				diffIDs = append(diffIDs, diffIDToAdd)
			}
		}
		configFile.RootFS = v1.RootFS{Type: "layers", DiffIDs: diffIDs}
	}

	// Winnie's speculative implementation. Ignore for now
	// // update the history
	// var layerEmpty bool
	// if len(layers) == 0 {
	// 	layerEmpty = true
	// }
	// historyItem := v1.History{
	// 	Author:     "Bazel",
	// 	Created:    v1.Time{time.Unix(unixTime, 0)},
	// 	CreatedBy:  "bazel build ...",
	// 	Comment:    *baseConfig,
	// 	EmptyLayer: layerEmpty,
	// }
	// configFile.History = append(configFile.History, historyItem)
	// if creationTime != nil {
	// 	rfcV1Time, err := time.Parse(time.RFC3339, *creationTime)
	// 	configFile.Created = v1.Time{rfcV1Time}
	// 	if err != nil {
	// 		log.Fatalf("Unable to parse creation time from RFC3339 formation: %v", err)
	// 	}
	// }

	// length of history is expected to match the length of diff_ids
	history := configFile.History
	var historyToAdd v1.History
	var currAuthor string
	if configFile.Author != "" {
		currAuthor = configFile.Author
	} else {
		currAuthor = "Unknown"
	}
	var currCreated v1.Time
	var zeroedVal v1.Time
	if configFile.Created == zeroedVal {
		currCreated = configFile.Created
	} else {
		currCreated = v1.Time{time.Unix(0, 0)}
	}

	for _, l := range layers {
		historyToAdd = v1.History{
			Author:    currAuthor,
			Created:   currCreated,
			CreatedBy: "bazel build ...",
		}
		if l == emptyFile {
			historyToAdd.EmptyLayer = true
		}
		history = append([]v1.History{historyToAdd}, history...)
	}
	configFile.History = history

	if len(entrypointPrefix) != 0 {
		newEntrypoint := append(configFile.Config.Entrypoint, entrypointPrefix...)
		configFile.Config.Entrypoint = newEntrypoint
	}

	// write out the updated config
	rawConfig, err := json.Marshal(configFile)
	if err != nil {
		log.Fatalf("Unable to read config struct into json object: %v", err)
	}
	err = ioutil.WriteFile(*outputConfig, rawConfig, os.ModePerm)
	if err != nil {
		log.Fatalf("Writing config to %s was unsuccessful: %v", *outputConfig, err)
	}

	log.Println("Successfully created Image Config.")
	log.Println("Successfully created Image Manifest.")
}
