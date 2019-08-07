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
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
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
	// the base config.json file.
	ConfigFile *v1.ConfigFile
	// where to write the modified config file to.
	OutputConfig string
	// the creation timestamp.
	//Accepted in integer or floating point seconds since Unix Epoch, RFC3339 date/time.
	CreationTimeString string
	// the username to run the commands under.
	User string
	// the working directory to set for the layer.
	Workdir string
	// if true, Entrypoint will be set to null.
	NullEntryPoint bool
	// if true, Command will be set to null.
	NullCmd bool
	// The operating system to creater docker image for.
	OperatingSystem string
	// The command that generated the image. Default bazel build...
	CreatedBy string
	// The author of the image. Default bazel.
	Author string
	// The labels used to augment those of the previous layer.
	LabelsArray []string
	// The ports used to augment those of the previous layer.
	Ports []string
	// The volumes used to augment those of the previous layer.
	Volumes []string
	// Prefix the entrypoint with the specified arguments.
	EntrypointPrefix []string
	// The environments to augment those of the previous layer.
	Env []string
	// Command to override the command of the previous layer.
	Command []string
	// Override entrypoint of previous layer.
	Entrypoint []string
	// The list of layer sha256 hashes that compose the image.
	Layer []string
	// A list of files from which to read substitutions of variables from.
	StampInfoFile []string
}

// validate ensures that CreatedBy and Author are set.
// based on current implementation, we expect them to never be empty.
func (o *OverrideConfigOpts) validate() error {
	if o.CreatedBy == "" {
		return errors.New("CreatedBy was not specified")
	}
	if o.Author == "" {
		return errors.New("Author was not specified")
	}

	return nil
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
func keyValueToMap(value []string) (map[string]string, error) {
	convMap := make(map[string]string)
	var temp []string
	for _, kvpair := range value {
		temp = strings.Split(kvpair, "=")
		if len(temp) != 2 {
			return convMap, errors.New("value in array are not of format key=value")
		}
		key, val := temp[0], temp[1]
		convMap[key] = val
	}
	return convMap, nil
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

	o := inp
	for k, v := range formatArgs {
		if vStr, ok := v.(string); ok {
			o = strings.ReplaceAll(o, fmt.Sprintf("{%s}", k), vStr)
		} else {
			return "", errors.New("argument to format is not of string type")
		}
	}
	return o, nil
}

// mapToKeyValue reverses a map to a '='-separated array of strings in {key}={value} format.
func mapToKeyValue(kvMap map[string]string) []string {
	keyVals := []string{}
	for k, v := range kvMap {
		keyVals = append(keyVals, fmt.Sprintf("%s=%s", k, v))
	}

	sort.Strings(keyVals)
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
		err := errors.New(fmt.Sprintf("environment variable %s does not exist as key in environment map", p))
		if err != nil {
			return fmt.Sprintf("%v", errors.Wrap(err, "failed to create new error"))
		}
		return fmt.Sprintf("%v", err)
	}

	expandedVar := os.Expand(value, mapper)
	if errorMet {
		return "", errors.New(fmt.Sprintf("variable substitution of %s was unsuccessful", value))
	}
	return expandedVar, nil
}

// getCreationTime returns the correct creation time for which to override the current config file.
func getCreationTime(overrideInfo *OverrideConfigOpts) (time.Time, error) {
	// createTime stores the input creation time with macros substituted.
	var createTime string
	var creationTime time.Time
	var err error
	// Parse for specific time formats.
	if overrideInfo.CreationTimeString != "" {
		var unixTime float64
		// Use stamp to as preliminary replacement.
		if createTime, err = Stamp(overrideInfo.CreationTimeString, overrideInfo.StampInfoFile); err != nil {
			return time.Unix(0, 0), errors.Wrapf(err, "unable to format creation time from BUILD_TIMESTAMP macros")
		}
		// If creationTime is parsable as a floating point type, assume unix epoch timestamp.
		// otherwise, assume RFC 3339 date/time format.
		unixTime, err := strconv.ParseFloat(createTime, 64)
		// Assume RFC 3339 date/time format. No err means it is parsable as floating point.
		if err == nil {
			// Ensure that the parsed time is within the floating point range.
			// Values > 1e11 are assumed to be unix epoch milliseconds.
			if unixTime > 1.0e+11 {
				unixTime = unixTime / 1000.0
			}
			// Construct a RFC 3339 date/time from Unix epoch.
			sec, dec := math.Modf(unixTime)
			creationTime = time.Unix(int64(sec), int64(dec*(1e9))).UTC()
		} else {
			creationTime, err = time.Parse(time.RFC3339, createTime)
			if err != nil {
				return time.Unix(0, 0), errors.Wrapf(err, "failed to parse the %s into float, so assuming RFC3339", createTime)
			}
		}
	}
	return creationTime, nil
}

// updateConfigInfo returns an updated version of the input infoToStamp.
func updateConfigInfo(overrideInfo *OverrideConfigOpts, infoToStamp []string) ([]string, error) {
	var infoStamped = infoToStamp
	for i, entry := range infoToStamp {
		stampedEntry, err := Stamp(entry, overrideInfo.StampInfoFile)
		if err != nil {
			return []string{}, errors.Wrapf(err, "unable to perform substitutions to Env variable %s", entry)
		}
		infoStamped[i] = stampedEntry
	}

	return infoStamped, nil
}

// resolveEnvironment returns a string array with fully substituted environment variables.
func resolveEnvironment(overrideInfo *OverrideConfigOpts, environMap map[string]string) ([]string, error) {
	var baseEnvMap = make(map[string]string)
	var err error
	if len(overrideInfo.ConfigFile.Config.Env) > 0 {
		baseEnvMap, err = keyValueToMap(overrideInfo.ConfigFile.Config.Env)
		if err != nil {
			return []string{}, errors.Wrapf(err, "error converting Config env array %v to map", overrideInfo.ConfigFile.Config.Env)
		}
	}

	for k, v := range environMap {
		var expanded string
		if expanded, err = resolveVariables(v, baseEnvMap); err != nil {
			return []string{}, errors.Wrapf(err, "unable to resolve environment variables in %s with content mapping at %s", k, v)
		}
		if _, ok := environMap[k]; ok {
			baseEnvMap[k] = expanded
		}
	}

	return mapToKeyValue(baseEnvMap), nil
}

// resolveLabels returns a map of labels to their extracted and stamped formats.
func resolveLabels(overrideInfo *OverrideConfigOpts) (map[string]string, error) {
	var labels = make(map[string]string)
	labels, err := keyValueToMap(overrideInfo.LabelsArray)
	if err != nil {
		return labels, errors.Wrapf(err, "error converting labels array %v to map", overrideInfo.LabelsArray)
	}
	var extractedValue string
	for label, value := range labels {
		if strings.HasPrefix(value, "@") {
			if extractedValue, err = extractValue(value); err != nil {
				return labels, errors.Wrap(err, "failed to extract the contents of labels file")
			}
			labels[label] = extractedValue
			continue
		}
		if strings.Contains(value, "{") {
			if extractedValue, err = Stamp(value, overrideInfo.StampInfoFile); err != nil {
				return labels, errors.Wrapf(err, "failed to format the string accordingly at %s", value)
			}
			labels[label] = extractedValue
		}
	}

	return labels, nil
}

// updateConfigLabels returns the set of labels to assign to config.
func updateConfigLabels(overrideInfo *OverrideConfigOpts, labels map[string]string) map[string]string {
	labelsMap := make(map[string]string)
	if len(overrideInfo.ConfigFile.Config.Labels) > 0 {
		labelsMap = overrideInfo.ConfigFile.Config.Labels
	}
	for k, v := range labels {
		labelsMap[k] = v
	}

	return labelsMap
}

// updateExposedPorts modifies the config's exposed ports based on the input ports.
func updateExposedPorts(overrideInfo *OverrideConfigOpts) error {
	for _, port := range overrideInfo.Ports {
		match, err := regexp.MatchString("[0-9]+/(tcp|udp)", port)
		if err != nil {
			return errors.Wrapf(err, "failed to successfully match regex to %s", port)
		}
		if match {
			// the port spec has the form 80/tcp, 1234/udp so simply use it as the key.
			overrideInfo.ConfigFile.Config.ExposedPorts[port] = struct{}{}
		} else {
			// assume tcp
			overrideInfo.ConfigFile.Config.ExposedPorts[port+"/tcp"] = struct{}{}
		}
	}

	return nil
}

// updateVolumes modifies the config's volumes based on the input volumes.
func updateVolumes(overrideInfo *OverrideConfigOpts) error {
	for _, volume := range overrideInfo.Volumes {
		overrideInfo.ConfigFile.Config.Volumes[volume] = struct{}{}
	}

	return nil
}

// updateConfigLayeres modifies the config's layers metadata based on the input layer IDs and history.
func updateConfigLayers(overrideInfo *OverrideConfigOpts, layerDigests []string, creationTime time.Time) error {
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
			var createdBy = overrideInfo.CreatedBy
			var authorToAdd = overrideInfo.Author

			if err := overrideInfo.validate(); err != nil {
				return errors.Wrapf(err, "unable to create a new config because the given options to override the existing image config/generate new config failed validation")
			}

			historyToAdd = v1.History{
				Author:    authorToAdd,
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

	return nil
}

// OverrideImageConfig updates the current image config file to reflect the given changes.
func OverrideImageConfig(overrideInfo *OverrideConfigOpts) error {
	overrideInfo.ConfigFile.Author = "Bazel"
	overrideInfo.ConfigFile.OS = overrideInfo.OperatingSystem
	overrideInfo.ConfigFile.Architecture = defaultProcArch

	var err error

	// creationTime is the RFC 3339 formatted time derived from createTime input.
	creationTime, err := time.Parse(time.RFC3339, defaultTimestamp)
	if err != nil {
		return errors.Wrapf(err, "unable to parse the default unix epoch time %s", defaultTimestamp)
	}
	if creationTime, err = getCreationTime(overrideInfo); err != nil {
		return errors.Wrap(err, "failed to correctly parse creation time from config")
	}
	overrideInfo.ConfigFile.Created = v1.Time{creationTime}

	if overrideInfo.NullEntryPoint {
		overrideInfo.ConfigFile.Config.Entrypoint = nil
	} else if len(overrideInfo.Entrypoint) > 0 {
		overrideEntryPoint, err := updateConfigInfo(overrideInfo, overrideInfo.Entrypoint[:])
		if err != nil {
			return errors.Wrap(err, "failed to correctly parse entrypoint from config")
		}
		overrideInfo.ConfigFile.Config.Entrypoint = overrideEntryPoint
	}

	if overrideInfo.NullCmd {
		overrideInfo.ConfigFile.Config.Cmd = nil
	} else if len(overrideInfo.Command) > 0 {
		overrideNullCmd, err := updateConfigInfo(overrideInfo, overrideInfo.Command[:])
		if err != nil {
			return errors.Wrap(err, "failed to correctly parse entrypoint from config")
		}
		overrideInfo.ConfigFile.Config.Cmd = overrideNullCmd
	}

	stampedUser, err := Stamp(overrideInfo.User, overrideInfo.StampInfoFile)
	if err != nil {
		errors.Wrapf(err, "unable to perform substitutions to user %s", overrideInfo.User)
	}
	overrideInfo.ConfigFile.Config.User = stampedUser

	var environMap map[string]string
	if environMap, err = keyValueToMap(overrideInfo.Env); err != nil {
		return errors.Wrapf(err, "error converting env array %v to map", overrideInfo.Env)
	}
	for key, valToBeStamped := range environMap {
		stampedValue, err := Stamp(valToBeStamped, overrideInfo.StampInfoFile)
		if err != nil {
			return errors.Wrapf(err, "error stamping value %s", valToBeStamped)
		}
		environMap[key] = stampedValue
	}
	// perform any substitutions of $VAR or ${VAR} with environment variables.
	if len(environMap) != 0 {
		overrideEnv, err := resolveEnvironment(overrideInfo, environMap)
		if err != nil {
			return errors.Wrap(err, "failed to correctly parse environment variables from config")
		}
		overrideInfo.ConfigFile.Config.Env = overrideEnv
	}

	var labels = make(map[string]string)
	if labels, err = resolveLabels(overrideInfo); err != nil {
		return errors.Wrap(err, "failed to correctly resolve labels from config")
	}
	if len(overrideInfo.LabelsArray) > 0 {
		labelsMap := updateConfigLabels(overrideInfo, labels)
		overrideInfo.ConfigFile.Config.Labels = labelsMap
	}

	if len(overrideInfo.Ports) > 0 {
		if len(overrideInfo.ConfigFile.Config.ExposedPorts) == 0 {
			overrideInfo.ConfigFile.Config.ExposedPorts = make(map[string]struct{})
		}
		if err = updateExposedPorts(overrideInfo); err != nil {
			return errors.Wrap(err, "failed to correctly update exposed ports from config")
		}
	}

	if len(overrideInfo.Volumes) > 0 {
		if len(overrideInfo.ConfigFile.Config.Volumes) == 0 {
			overrideInfo.ConfigFile.Config.Volumes = make(map[string]struct{})
		}
		if err = updateVolumes(overrideInfo); err != nil {
			return errors.Wrap(err, "failed to correctly update volumes from config")
		}
	}

	if overrideInfo.Workdir != "" {
		stampedWorkdir, err := Stamp(overrideInfo.Workdir, overrideInfo.StampInfoFile)
		if err != nil {
			return errors.Wrapf(err, "unable to stamp the working directory %s", overrideInfo.Workdir)
		}
		overrideInfo.ConfigFile.Config.WorkingDir = stampedWorkdir
	}

	// layerDigests are diffIDs extracted from each layer file.
	layerDigests := []string{}
	for _, l := range overrideInfo.Layer {
		newLayer, err := extractValue(l)
		if err != nil {
			return errors.Wrap(err, "failed to extract the contents of layer file: %v")
		}
		layerDigests = append(layerDigests, newLayer)
	}
	if err = updateConfigLayers(overrideInfo, layerDigests, creationTime); err != nil {
		return errors.Wrap(err, "failed to correctly update layers from config")
	}

	if len(overrideInfo.EntrypointPrefix) != 0 {
		newEntrypoint := append(overrideInfo.ConfigFile.Config.Entrypoint, overrideInfo.EntrypointPrefix...)
		overrideInfo.ConfigFile.Config.Entrypoint = newEntrypoint
	}

	if err = writeConfig(overrideInfo.ConfigFile, overrideInfo.OutputConfig); err != nil {
		return errors.Wrap(err, "failed to create updated Image Config.")
	}

	return nil
}

// writeConfig writes a json representation of a config file to outPath.
func writeConfig(configFile *v1.ConfigFile, outPath string) error {
	rawConfig, err := json.Marshal(configFile)
	if err != nil {
		return errors.Wrap(err, "unable to read config struct into json object")
	}

	err = ioutil.WriteFile(outPath, rawConfig, os.ModePerm)
	if err != nil {
		return errors.Wrapf(err, "writing config to %s was unsuccessful", outPath)
	}

	return nil
}
