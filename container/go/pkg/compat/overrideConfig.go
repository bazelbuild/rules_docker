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
	"sort"
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

// OverrideConfigOpts holds all configuration settings for the newly outputted config file.
type OverrideConfigOpts struct {
	ConfigFile         *v1.ConfigFile
	OutputConfig       string
	CreationTimeString string
	User               string
	Workdir            string
	NullEntryPoint     string
	NullCmd            string
	OperatingSystem    string
	CreatedByArg       string
	AuthorArg          string
	LabelsArray        []string
	Ports              []string
	Volumes            []string
	EntrypointPrefix   []string
	Env                []string
	Command            []string
	Entrypoint         []string
	Layer              []string
	StampInfoFile      []string
}

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
		// scanner reads line by line and discards '\n' character by default.
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

// mapToKeyValue reverses a map to a '='-separated array of strings in {key}={value} format.
func mapToKeyValue(kvMap map[string]string) []string {
	keyVals := []string{}
	concatenated := ""
	for k, v := range kvMap {
		concatenated = k + "=" + v
		keyVals = append(keyVals, concatenated)
	}

	sort.Sort(sort.StringSlice(keyVals))
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

// OverrideImageConfig updates the current image config file to reflect the given changes.
func OverrideImageConfig(overrideInfo *OverrideConfigOpts) error {
	overrideInfo.ConfigFile.Author = "Bazel"
	overrideInfo.ConfigFile.OS = overrideInfo.OperatingSystem
	overrideInfo.ConfigFile.Architecture = defaultProcArch

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
	if overrideInfo.CreationTimeString != "" {
		log.Printf("The CreationTimeString is: %s", overrideInfo.CreationTimeString)
		var unixTime float64
		// Use stamp to as preliminary replacement.
		if createTime, err = Stamp(overrideInfo.CreationTimeString, overrideInfo.StampInfoFile); err != nil {
			return errors.Wrapf(err, "Unable to format creation time from BUILD_TIMESTAMP macros")
		}
		log.Printf("The first createTime is: %v", createTime)
		// If creationTime is parsable as a floating point type, assume unix epoch timestamp.
		// otherwise, assume RFC 3339 date/time format.
		unixTime, err = strconv.ParseFloat(createTime, 64)
		log.Printf("the unixTime after strconv is: %f", unixTime)
		// Assume RFC 3339 date/time format. No err means it is parsable as floating point.
		if err == nil {
			log.Println("nani")
			// Ensure that the parsed time is within the floating point range.
			// Values > 1e11 are assumed to be unix epoch milliseconds.
			if unixTime > 1.0e+11 {
				unixTime = unixTime / 1000.0
			}
			// Construct a RFC 3339 date/time from Unix epoch.
			sec, dec := math.Modf(unixTime)
			log.Printf("sec: %v, dec: %v", sec, dec)
			creationTime = time.Unix(int64(sec), int64(dec*(1e9))).UTC()
		} else {
			creationTime, err = time.Parse(time.RFC3339, createTime)
			if err != nil {
				return errors.Wrapf(err, "failed to parse the %s into float, so assuming RFC3339", createTime)
			}
		}
	}
	log.Printf("the assigned CreationTime is: %v", creationTime)
	overrideInfo.ConfigFile.Created = v1.Time{creationTime}

	if overrideInfo.NullEntryPoint == "True" {
		overrideInfo.ConfigFile.Config.Entrypoint = nil
	} else if len(overrideInfo.Entrypoint) > 0 {
		for i, entry := range overrideInfo.Entrypoint {
			stampedEntry, err := Stamp(entry, overrideInfo.StampInfoFile)
			if err != nil {
				return errors.Wrapf(err, "Unable to perform substitutions to Env variable %s", entry)
			}
			overrideInfo.Entrypoint[i] = stampedEntry
		}
		overrideInfo.ConfigFile.Config.Entrypoint = overrideInfo.Entrypoint
	}

	if overrideInfo.NullCmd == "True" {
		log.Println("hellooooo")
		overrideInfo.ConfigFile.Config.Cmd = nil
	} else if len(overrideInfo.Command) > 0 {
		for i, cmd := range overrideInfo.Command {
			stampedCmd, err := Stamp(cmd, overrideInfo.StampInfoFile)
			if err != nil {
				return errors.Wrapf(err, "Unable to perform substitutions to Env variable %s", cmd)
			}
			overrideInfo.Command[i] = stampedCmd
		}
		overrideInfo.ConfigFile.Config.Cmd = overrideInfo.Command
	}

	log.Printf("the stamped Command: %v", overrideInfo.Command)

	stampedUser, err := Stamp(overrideInfo.User, overrideInfo.StampInfoFile)
	if err != nil {
		errors.Wrapf(err, "Unable to perform substitutions to user %s", overrideInfo.User)
	}
	overrideInfo.ConfigFile.Config.User = stampedUser

	environMap := keyValueToMap(overrideInfo.Env)
	for key, valToBeStamped := range environMap {
		stampedValue, err := Stamp(valToBeStamped, overrideInfo.StampInfoFile)
		if err != nil {
			return errors.Wrapf(err, "Error stamping value %s", valToBeStamped)
		}
		environMap[key] = stampedValue
	}
	// perform any substitutions of $VAR or ${VAR} with environment variables.
	if len(environMap) != 0 {
		var baseEnvMap map[string]string

		if len(overrideInfo.ConfigFile.Config.Env) > 0 {
			baseEnvMap = keyValueToMap(overrideInfo.ConfigFile.Config.Env)
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
		overrideInfo.ConfigFile.Config.Env = mapToKeyValue(baseEnvMap)
	}

	labels := keyValueToMap(overrideInfo.LabelsArray)
	var extractedValue string
	for label, value := range labels {
		if strings.HasPrefix(value, "@") {
			if extractedValue, err = extractValue(value); err != nil {
				return errors.Wrap(err, "Failed to extract the contents of labels file")
			}
			labels[label] = extractedValue
			continue
		}
		if strings.Contains(value, "{") {
			if extractedValue, err = Stamp(value, overrideInfo.StampInfoFile); err != nil {
				return errors.Wrapf(err, "Failed to format the string accordingly at %s", value)
			}
			labels[label] = extractedValue
		}
	}
	if len(overrideInfo.LabelsArray) > 0 {
		labelsMap := make(map[string]string)
		if len(overrideInfo.ConfigFile.Config.Labels) > 0 {
			labelsMap = overrideInfo.ConfigFile.Config.Labels
		}
		for k, v := range labels {
			labelsMap[k] = v
		}
		overrideInfo.ConfigFile.Config.Labels = labelsMap
	}

	if len(overrideInfo.Ports) > 0 {
		if len(overrideInfo.ConfigFile.Config.ExposedPorts) == 0 {
			overrideInfo.ConfigFile.Config.ExposedPorts = make(map[string]struct{})
		}
		for _, port := range overrideInfo.Ports {
			match, err := regexp.MatchString("[0-9]+/(tcp|udp)", port)
			if err != nil {
				return errors.Wrapf(err, "Failed to successfully match regex to %s", port)
			}
			if match {
				// the port spec has the form 80/tcp, 1234/udp so simply use it as the key.
				overrideInfo.ConfigFile.Config.ExposedPorts[port] = struct{}{}
			} else {
				// assume tcp
				overrideInfo.ConfigFile.Config.ExposedPorts[port+"/tcp"] = struct{}{}
			}
		}
	}

	if len(overrideInfo.Volumes) > 0 {
		if len(overrideInfo.ConfigFile.Config.Volumes) == 0 {
			overrideInfo.ConfigFile.Config.Volumes = make(map[string]struct{})
		}
		for _, volume := range overrideInfo.Volumes {
			overrideInfo.ConfigFile.Config.Volumes[volume] = struct{}{}
		}
	}

	if overrideInfo.Workdir != "" {
		stampedWorkdir, err := Stamp(overrideInfo.Workdir, overrideInfo.StampInfoFile)
		if err != nil {
			return errors.Wrapf(err, "Unable to stamp the working directory %s", overrideInfo.Workdir)
		}
		overrideInfo.ConfigFile.Config.WorkingDir = stampedWorkdir
	}

	// layerDigests are diffIDs extracted from each layer file.
	layerDigests := []string{}
	for _, l := range overrideInfo.Layer {
		newLayer, err := extractValue(l)
		if err != nil {
			return errors.Wrap(err, "Failed to extract the contents of layer file: %v")
		}
		layerDigests = append(layerDigests, newLayer)
	}
	// diffIDs are ordered from bottom-most to top-most.
	diffIDs := []v1.Hash{}
	if len(overrideInfo.ConfigFile.RootFS.DiffIDs) > 0 {
		diffIDs = overrideInfo.ConfigFile.RootFS.DiffIDs
	}
	if len(overrideInfo.Layer) > 0 {
		var diffIDToAdd v1.Hash
		for _, diffID := range layerDigests {
			if diffID != emptySHA256Digest() {
				diffIDToAdd = v1.Hash{Algorithm: "sha256", Hex: diffID}
				diffIDs = append(diffIDs, diffIDToAdd)
			}
		}
		overrideInfo.ConfigFile.RootFS = v1.RootFS{Type: "layers", DiffIDs: diffIDs}

		// length of history is expected to match the length of diff_ids.
		history := []v1.History{}
		if len(overrideInfo.ConfigFile.History) > 0 {
			history = overrideInfo.ConfigFile.History
		}
		var historyToAdd v1.History

		for _, l := range layerDigests {
			var createdBy = overrideInfo.CreatedByArg
			if createdBy == "" {
				createdBy = "Unknown"
			}

			var Author = overrideInfo.AuthorArg
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
			// prepend to history list.
			history = append([]v1.History{historyToAdd}, history...)
		}
		overrideInfo.ConfigFile.History = history
	}

	if len(overrideInfo.EntrypointPrefix) != 0 {
		newEntrypoint := append(overrideInfo.ConfigFile.Config.Entrypoint, overrideInfo.EntrypointPrefix...)
		overrideInfo.ConfigFile.Config.Entrypoint = newEntrypoint
	}

	err = WriteConfig(overrideInfo.ConfigFile, overrideInfo.OutputConfig)
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
