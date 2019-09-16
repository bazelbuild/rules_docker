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
	"io"
	"io/ioutil"
	"math"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/pkg/errors"
)

const (
	// defaultProcArch is the default architecture type based on legacy create_image_config.py.
	defaultProcArch = "amd64"
	// defaultTimeStamp is the unix epoch 0 time representation in 32 bits.
	defaultTimestamp = "1970-01-01T00:00:00Z"
)

// OverrideConfigOpts holds all configuration settings for the newly outputted config file.
type OverrideConfigOpts struct {
	// ConfigFile is the base config.json file.
	ConfigFile *v1.ConfigFile
	// OutputConfig is where to write the modified config file to.
	OutputConfig string
	// CreationTimeString is the creation timestamp.
	// Accepted in integer or floating point seconds since Unix Epoch, RFC3339 date/time.
	CreationTimeString string
	// User is the username to run the commands under.
	User string
	// Workdir is the working directory to set for the layer.
	Workdir string
	// NullEntrypoint indicates if there is an entrypoint.
	// If true, Entrypoint will be set to null.
	NullEntryPoint bool
	// NullCmd indicates if there is a command.
	// If true, Command will be set to null.
	NullCmd bool
	// OperatingSystem is the operating system to creater docker image for.
	OperatingSystem string
	// CreatedBy is the command that generated the image. Default
	// "bazel build ...".
	CreatedBy string
	// Author is the author of the image. Default bazel.
	Author string
	// LabelsArray is the labels used to augment those of the previous layer.
	LabelsArray []string
	// Ports are the ports used to augment those of the previous layer.
	Ports []string
	// Volumes are the volumes used to augment those of the previous layer.
	Volumes []string
	// EntrypointPrefix is the prefix to the entrypoint with the specified arguments.
	EntrypointPrefix []string
	// Env are the environments to augment those of the previous layer.
	Env []string
	// Command are the command(s) to override those of the previous layer.
	Command []string
	// Entrypoint are the new entrypoints to override entrypoint of previous layer.
	Entrypoint []string
	// Layer is the list of layer sha256 hashes that compose the image for which the config is written.
	Layer []string
	// Stamper will be used to stamp values in the image config.
	Stamper *Stamper
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
			return convMap, errors.New(fmt.Sprintf("%q is not of format key=value", kvpair))
		}
		key, val := temp[0], temp[1]
		convMap[key] = val
	}
	return convMap, nil
}

// stampSubstitution is a key value pair used by 'Stamper' to convert values in
// the format "{key}" to "value".
type stampSubstitution struct {
	key   string
	value string
}

// Stamper provides functionality to stamp a given string based on key value
// pairs from a stamp info text file.
// Each stamp info text file can specify key value pairs in the following
// format:
// KEY1 VALUE1
// KEY2 VALUE2
// ...
// This will result in the stamper making the following substitutions in the
// specified order:
// {KEY1} -> VALUE1
// {KEY2} -> VALUE2
// ...
type Stamper struct {
	// subs is a list of substitutions done by the stamper for any given string.
	subs []stampSubstitution
}

// Stamp stamps the given value.
func (s *Stamper) Stamp(val string) string {
	for _, sb := range s.subs {
		val = strings.ReplaceAll(val, sb.key, sb.value)
	}
	return val
}

// StampAll stamps all given values and returns a list with the result. The
// given list is not modified.
func (s *Stamper) StampAll(vals []string) []string {
	result := []string{}
	for _, v := range vals {
		result = append(result, s.Stamp(v))
	}
	return result
}

// uniquify uniquifies the substitutions in the given stamper. If a key appears
// multiple times, the latest entry for the key will be preserved and the
// earlier entries discarded.
func (s *Stamper) uniquify() {
	lookup := make(map[string]bool)
	reverseSubs := []stampSubstitution{}
	// Scan in reverse order rejecting duplicates.
	for i := len(s.subs) - 1; i >= 0; i-- {
		if _, ok := lookup[s.subs[i].key]; ok {
			continue
		}
		lookup[s.subs[i].key] = true
		reverseSubs = append(reverseSubs, s.subs[i])
	}
	s.subs = reverseSubs
	for i, j := 0, len(s.subs)-1; i <= j; i, j = i+1, j-1 {
		s.subs[i], s.subs[j] = s.subs[j], s.subs[i]
	}
}

// loadSubs loads key value substitutions from the reader representing a
// Bazel stamp file.
func (s *Stamper) loadSubs(r io.Reader) error {
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		line := strings.Split(sc.Text(), " ")
		if len(line) < 2 {
			return errors.Errorf("line %q in stamp info file did not split into expected number of tokens, got %d, want >=2", sc.Text(), len(line))
		}
		s.subs = append(s.subs, stampSubstitution{
			key:   fmt.Sprintf("{%s}", line[0]),
			value: strings.Join(line[1:], " "),
		})
	}
	return nil
}

// NewStamper creates a Stamper object initialized to stamp strings with the key
// value pairs in the given stamp info files.
func NewStamper(stampInfoFiles []string) (*Stamper, error) {
	result := new(Stamper)
	for _, s := range stampInfoFiles {
		f, err := os.Open(s)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to open stamp info file %s", s)
		}
		defer f.Close()

		if err := result.loadSubs(f); err != nil {
			return nil, errors.Wrapf(err, "error loading stamp info from %s", s)
		}
	}
	result.uniquify()
	return result, nil
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
func expandEnvVars(val string, env map[string]string) string {
	return os.Expand(val, func(k string) string {
		v, ok := env[k]
		// If the variable doesn't exist, return the key as is which mimics the
		// behavior of the legacy python config creator.
		// If the key was specified was "${k}", this will actually change it to
		// "$k" while the old python code would have retained the curly braces.
		// However, functionally, this shouldn't be a problem.
		if !ok {
			return "$" + k
		}
		return v
	})
}

// getCreationTime returns the correct creation time for which to override the current config file.
func getCreationTime(overrideInfo *OverrideConfigOpts) (time.Time, error) {
	var creationTime time.Time
	var err error
	if overrideInfo.CreationTimeString == "" {
		creationTime, err = time.Parse(time.RFC3339, defaultTimestamp)
		if err != nil {
			return time.Time{}, errors.Wrapf(err, "unable to parse the default unix epoch time %s", defaultTimestamp)
		}
		return creationTime, nil
	}
	// Parse for specific time formats.
	var unixTime float64
	stampedTime := overrideInfo.Stamper.Stamp(overrideInfo.CreationTimeString)
	// If creationTime is parsable as a floating point type, assume unix epoch timestamp.
	// otherwise, assume RFC 3339 date/time format.
	unixTime, err = strconv.ParseFloat(stampedTime, 64)
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
		creationTime, err = time.Parse(time.RFC3339, stampedTime)
		if err != nil {
			return time.Time{}, errors.Wrapf(err, "failed to parse %q as RFC3339. Assumed format to be RFC3339 as it failed to parse as a float as well", stampedTime)
		}
	}

	return creationTime, nil
}

// resolveEnvironment returns a string array with fully substituted environment variables.
func resolveEnvironment(overrideInfo *OverrideConfigOpts, environMap map[string]string) ([]string, error) {
	var baseEnvMap = make(map[string]string)
	var err error
	if len(overrideInfo.ConfigFile.Config.Env) > 0 {
		baseEnvMap, err = keyValueToMap(overrideInfo.ConfigFile.Config.Env)
		if err != nil {
			return nil, errors.Wrapf(err, "error converting Config env array %v to map", overrideInfo.ConfigFile.Config.Env)
		}
	}
	result := make(map[string]string)
	for k, v := range baseEnvMap {
		result[k] = v
	}
	for k, v := range environMap {
		var expanded string
		expanded = expandEnvVars(v, baseEnvMap)
		result[k] = expanded
	}

	return mapToKeyValue(result), nil
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
			labels[label] = overrideInfo.Stamper.Stamp(value)
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
			if err := overrideInfo.validate(); err != nil {
				return errors.Wrapf(err, "unable to create a new config because the given options to override the existing image config/generate new config failed validation")
			}

			historyToAdd = v1.History{
				Author:    overrideInfo.Author,
				Created:   v1.Time{creationTime},
				CreatedBy: overrideInfo.CreatedBy,
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

// updateConfig updates the image config specified in the given
// OverrideConfigOpts using the options specified in the OverrideConfigOpts.
func updateConfig(overrideInfo *OverrideConfigOpts) error {
	overrideInfo.ConfigFile.Author = overrideInfo.Author
	overrideInfo.ConfigFile.OS = overrideInfo.OperatingSystem
	overrideInfo.ConfigFile.Architecture = defaultProcArch

	creationTime, err := getCreationTime(overrideInfo)
	// creationTime is the RFC 3339 formatted time derived from createTime input.
	if err != nil {
		return errors.Wrap(err, "failed to parse creation time from config")
	}
	overrideInfo.ConfigFile.Created = v1.Time{creationTime}

	if overrideInfo.NullEntryPoint {
		overrideInfo.ConfigFile.Config.Entrypoint = nil
	} else if len(overrideInfo.Entrypoint) > 0 {
		overrideInfo.ConfigFile.Config.Entrypoint = overrideInfo.Stamper.StampAll(overrideInfo.Entrypoint)
	}

	if overrideInfo.NullCmd {
		overrideInfo.ConfigFile.Config.Cmd = nil
	} else if len(overrideInfo.Command) > 0 {
		overrideInfo.ConfigFile.Config.Cmd = overrideInfo.Stamper.StampAll(overrideInfo.Command)
	}
	if overrideInfo.User != "" {
		overrideInfo.ConfigFile.Config.User = overrideInfo.Stamper.Stamp(overrideInfo.User)
	}

	environMap, err := keyValueToMap(overrideInfo.Env)
	if err != nil {
		return errors.Wrapf(err, "error converting env array %v to map", overrideInfo.Env)
	}
	for k, v := range environMap {
		environMap[k] = overrideInfo.Stamper.Stamp(v)
	}
	// perform any substitutions of $VAR or ${VAR} with environment variables.
	if len(environMap) != 0 {
		overrideEnv, err := resolveEnvironment(overrideInfo, environMap)
		if err != nil {
			return errors.Wrap(err, "failed to parse environment variables from config")
		}
		overrideInfo.ConfigFile.Config.Env = overrideEnv
	}

	labels, err := resolveLabels(overrideInfo)
	if err != nil {
		return errors.Wrap(err, "failed to resolve labels from config")
	}
	if len(overrideInfo.LabelsArray) > 0 {
		labelsMap := updateConfigLabels(overrideInfo, labels)
		overrideInfo.ConfigFile.Config.Labels = labelsMap
	}

	if len(overrideInfo.Ports) > 0 {
		if len(overrideInfo.ConfigFile.Config.ExposedPorts) == 0 {
			overrideInfo.ConfigFile.Config.ExposedPorts = make(map[string]struct{})
		}
		if err := updateExposedPorts(overrideInfo); err != nil {
			return errors.Wrap(err, "failed to update exposed ports from config")
		}
	}

	if len(overrideInfo.Volumes) > 0 {
		if len(overrideInfo.ConfigFile.Config.Volumes) == 0 {
			overrideInfo.ConfigFile.Config.Volumes = make(map[string]struct{})
		}
		if err := updateVolumes(overrideInfo); err != nil {
			return errors.Wrap(err, "failed to update volumes from config")
		}
	}

	if overrideInfo.Workdir != "" {
		overrideInfo.ConfigFile.Config.WorkingDir = overrideInfo.Stamper.Stamp(overrideInfo.Workdir)
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
	if err := updateConfigLayers(overrideInfo, layerDigests, creationTime); err != nil {
		return errors.Wrap(err, "failed to correctly update layers from config")
	}

	if len(overrideInfo.EntrypointPrefix) != 0 {
		newEntrypoint := append(overrideInfo.ConfigFile.Config.Entrypoint, overrideInfo.EntrypointPrefix...)
		overrideInfo.ConfigFile.Config.Entrypoint = newEntrypoint
	}
	return nil
}

// OverrideImageConfig updates the current image config file to reflect the
// given changes and writes out the updated image config to the file specified
// in the given options.
func OverrideImageConfig(overrideInfo *OverrideConfigOpts) error {
	if err := updateConfig(overrideInfo); err != nil {
		return errors.Wrap(err, "failed to create/update image config")
	}
	if err := writeConfig(overrideInfo.ConfigFile, overrideInfo.OutputConfig); err != nil {
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
