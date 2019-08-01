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

package compat

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"math"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/pkg/errors"

	v1 "github.com/google/go-containerregistry/pkg/v1"
)

const (
	// defaultProcArch is the default architecture type based on legacy create_image_config.py.
	defaultProcArch = "amd64"
	// defaultTimeStamp is the unix epoch 0 time representation in 32 bits.
	defaultTimestamp = "1970-01-01T00:00:00Z"
)

// emptySHA256Digest returns the sha256 sum of an empty string.
func emptySHA256Digest() (empty string) {
	b := sha256.Sum256([]byte(""))
	empty = hex.EncodeToString(b[:])
	return
}

// extractValue returns the contents of a file pointed to by value if it starts with a '@'.
func extractValue(value string) (string, error) {
	if strings.HasPrefix(value, "@") {
		f, err := os.Open(value[1:])
		// f, err := os.Open(value)
		defer f.Close()
		shaHash, err := ioutil.ReadAll(f)
		if err != nil {
			return "", errors.Wrapf(err, "failed to read content from file %s", value)
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

// formateWithMap takes all variables of format {{.VAR}} in the input string `format`
// and replaces it according to the map of parameters to values in `params`.
func formatWithMap(format string, params formattedString) string {
	msg := &bytes.Buffer{}
	template.Must(template.New("").Parse(format)).Execute(msg, params)
	return msg.String()
}

// Stamp provides the substitutions of variables inside {} using info in file pointed to
// by stampInfoFile.
func Stamp(inp string, stampInfoFile []string) (string, error) {
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
	fmt.Printf("environment override %v", environment)
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
		err := errors.New("environment variable sought after does not exist in environement map")
		if err != nil {
			errors.Wrap(err, "failed to create new error")
		}
		return "", err
	}
	return os.Expand(value, mapper), nil
}

// OverrideContent updates the current image config file to reflect the given changes.
func OverrideContent(configFile *v1.ConfigFile, outputConfig, creationTimeString, user, workdir, nullEntryPoint, nullCmd, operatingSystem, createdByArg, authorArg string, labelsArray, ports, volumes, entrypointPrefix, env, command, entrypoint, layer, stampInfoFile []string) error {
	configFile.Author = "Bazel"
	configFile.OS = operatingSystem
	configFile.Architecture = defaultProcArch

	var err error
	// createTime stores the input creation time with macros substituted.
	var createTime string
	// creationTime is the RFC 3339 formatted time derived from createTime input.
	creationTime, err := time.Parse(time.RFC3339, defaultTimestamp)
	log.Printf("the very very first creationTime: %v", creationTime)
	if err != nil {
		return errors.Wrap(err, "Unable to parse the default unix epoch time 1970-01-01T00:00:00Z")
	}

	// Parse for specific time formats.
	if creationTimeString != "" {
		log.Printf("The creationTimeString is: %s", creationTimeString)
		var unixTime float64
		// Use stamp to as preliminary replacement.
		if createTime, err = Stamp(creationTimeString, stampInfoFile); err != nil {
			return errors.Wrapf(err, "Unable to format creation time from BUILD_TIMESTAMP macros")
		}
		log.Printf("The first createTime is: %v", createTime)
		// If creationTime is parsable as a floating point type, assume unix epoch timestamp.
		// otherwise, assume RFC 3339 date/time format.
		unixTime, err = strconv.ParseFloat(createTime, 64)
		log.Printf("the unixTime after strconv is: %f", unixTime)
		// Assume RFC 3339 date/time format. No err means it is parsable as floating point.
		if err == nil {
			// Ensure that the parsed time is within the floating point range.
			// Values > 1e11 are assumed to be unix epoch milliseconds.
			if unixTime > 1.0e+11 {
				// log.Println("we are less and milliseconds")
				unixTime = unixTime / 1000.0
			}
			// Construct a RFC 3339 date/time from Unix epoch.
			// stringFromFloat := strconv.FormatFloat(unixTime, 'f', 6, 64)
			// log.Printf("The stringFromFloat unixTime to RFC is: %s", stringFromFloat)
			// creationTime, err = time.Parse(time.RFC3339, stringFromFloat)
			sec, dec := math.Modf(unixTime)
			log.Printf("sec: %v, dec: %v", sec, dec)
			creationTime = time.Unix(int64(sec), int64(dec*(1e9))).UTC()
			// 1970-01-01T00:00:00Z
			// creationTime = creationTime.UTC().Format("2006-01-02T15:04:05.00Z0700")
			// stringFormatCorrect := creationTime.UTC().Format("2006-01-02T15:04:05.000000Z0700")
			//log.Printf("the formated creationTime: %s", stringFormatCorrect)
			// creationTime, _ = time.Parse(time.RFC3339, stringFormatCorrect)
			//log.Printf("stringFormatCorrect into time object: %v", creationTime)
			//creationTime, _ = time.Parse(time.RFC3339, creationTime.Format(time.RFC3339))
			//log.Printf("The second creationTime is: %v", creationTime)
			//if err != nil {
			//return errors.Wrapf(err, "Unable to convert parsed RFC3339 time to time.Time")
			//}
		}
	}
	log.Printf("the assigned CreationTime is: %v", creationTime)
	configFile.Created = v1.Time{creationTime}

	// 	if len(configFile.Config.Entrypoint) == 0 && nullEntryPoint == "True" {
	if nullEntryPoint == "True" {
		configFile.Config.Entrypoint = nil
	} else if len(entrypoint) > 0 {
		// have to Stamp each entry and assign to config entries accordingly.
		for i, entry := range entrypoint {
			stampedEntry, err := Stamp(entry, stampInfoFile)
			if err != nil {
				return errors.Wrapf(err, "Unable to perform substitutions to env variable %s", entry)
			}
			entrypoint[i] = stampedEntry
		}
		configFile.Config.Entrypoint = entrypoint
	}

	if nullCmd == "True" {
		log.Println("hellooooo")
		configFile.Config.Cmd = nil
	} else if len(command) > 0 {
		for i, cmd := range command {
			stampedCmd, err := Stamp(cmd, stampInfoFile)
			if err != nil {
				return errors.Wrapf(err, "Unable to perform substitutions to env variable %s", cmd)
			}
			command[i] = stampedCmd
		}
		configFile.Config.Cmd = command
	}
	// else {
	// 	configFile.Config.Cmd = nil
	// }

	log.Printf("the stamped command: %v", command)

	// if user != "" {
	stampedUser, err := Stamp(user, stampInfoFile)
	if err != nil {
		errors.Wrapf(err, "Unable to perform substitutions to user %s", user)
	}
	configFile.Config.User = stampedUser

	environMap := keyValueToMap(env)
	// do any preliminary substitutions of macros (i.e no '$') by stamp info files.
	// (this is the "new" environment we are passing into overriden).
	for key, valToBeStamped := range environMap {
		stampedValue, err := Stamp(valToBeStamped, stampInfoFile)
		if err != nil {
			return errors.Wrapf(err, "Error stamping value %s", valToBeStamped)
		}
		environMap[key] = stampedValue
	}
	// perform any substitutions of $VAR or ${VAR} with environment variables
	if len(environMap) != 0 {
		var baseEnvMap map[string]string

		if len(configFile.Config.Env) > 0 {
			baseEnvMap = keyValueToMap(configFile.Config.Env)
		} else {
			baseEnvMap = make(map[string]string)
		}
		for k, v := range environMap {
			var expanded string
			if expanded, err = resolveVariables(v, baseEnvMap); err != nil {
				return errors.Wrapf(err, "Unable to resolve environment variables in %s with content mapping at %s", k, v)
			}
			if _, ok := environMap[k]; ok {
				baseEnvMap[k] = expanded
			}
		}
		configFile.Config.Env = mapToKeyValue(baseEnvMap)
	}

	labels := keyValueToMap(labelsArray)
	var extractedValue string
	for label, value := range labels {
		if strings.HasPrefix(value, "@") {
			if extractedValue, err = extractValue(value); err != nil {
				return errors.Wrap(err, "Failed to extract the contents of labels file: %v")
			}
			labels[label] = extractedValue
			continue
		}
		if strings.Contains(value, "{") {
			if extractedValue, err = Stamp(value, stampInfoFile); err != nil {
				return errors.Wrapf(err, "Failed to format the string accordingly at %s", value)
			}
			labels[label] = extractedValue
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
			match, err := regexp.MatchString("[0-9]+/(tcp|udp)", port)
			if err != nil {
				return errors.Wrapf(err, "Failed to successfully match regex to %s", port)
			}
			if match {
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

	if workdir != "" {
		stampedWorkdir, err := Stamp(workdir, stampInfoFile)
		if err != nil {
			return errors.Wrapf(err, "Unable to stamp the working directory %s", workdir)
		}
		configFile.Config.WorkingDir = stampedWorkdir
	}

	layerDigests := []string{}
	for _, l := range layer {
		newLayer, err := extractValue(l)
		if err != nil {
			return errors.Wrap(err, "Failed to extract the contents of layer file: %v")
		}
		layerDigests = append(layerDigests, newLayer)
	}
	// diffIDs are ordered from bottom-most to top-most.
	// []Hash type
	diffIDs := configFile.RootFS.DiffIDs
	if len(layer) > 0 {
		var diffIDToAdd v1.Hash
		for _, layer := range layerDigests {
			if layer != emptySHA256Digest() {
				diffIDToAdd = v1.Hash{Algorithm: "sha256", Hex: layer}
				diffIDs = append(diffIDs, diffIDToAdd)
			}
		}
		configFile.RootFS = v1.RootFS{Type: "layers", DiffIDs: diffIDs}

		// length of history is expected to match the length of diff_ids.
		history := configFile.History
		var historyToAdd v1.History

		for _, l := range layerDigests {
			var createdBy = createdByArg
			if createdBy == "" {
				createdBy = "Unknown"
			}

			var Author = authorArg
			if Author == "" {
				Author = "Unknown"
			}

			historyToAdd = v1.History{
				Author:    Author,
				Created:   v1.Time{creationTime},
				CreatedBy: createdBy,
			}
			if l == emptySHA256Digest() {
				historyToAdd.EmptyLayer = true
			}
			// prepend to history.
			history = append([]v1.History{historyToAdd}, history...)
		}
		configFile.History = history
	}

	if len(entrypointPrefix) != 0 {
		newEntrypoint := append(configFile.Config.Entrypoint, entrypointPrefix...)
		configFile.Config.Entrypoint = newEntrypoint
	}

	err = WriteConfig(configFile, outputConfig)
	if err != nil {
		return errors.Wrap(err, "Failed to create updated Image Config.")
	}

	return nil
}

// WriteConfig writes a json representation of a config file to outPath.
func WriteConfig(configFile *v1.ConfigFile, outPath string) error {
	rawConfig, err := json.Marshal(configFile)

	if err != nil {
		return errors.Wrap(err, "Unable to read config struct into json object")
	}
	err = ioutil.WriteFile(outPath, rawConfig, os.ModePerm)
	if err != nil {
		return errors.Wrapf(err, "Writing config to %s was unsuccessful", outPath)
	}

	return nil
}
