// Copyright 2017 The Bazel Authors. All rights reserved.
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

package main

import (
	"flag"
	"fmt"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"log"
	"os"

	"github.com/bazelbuild/rules_docker/contrib/go/pkg/metadata"
)

var (
	outFile = flag.String("outFile", "", "Output merged YAML file to generate.")
)

// strArgList implements a command line flag that can be specified multiple
// times to define a list of values.
type strArgList struct {
	// Args is the list of command line flags.
	Args []string
}

func (l *strArgList) String() string {
	return fmt.Sprintf("%v", l.Args)
}

// Set appends the given value for a particular occurance of the flag to the
// list of flag values.
func (l *strArgList) Set(value string) error {
	l.Args = append(l.Args, value)
	return nil
}

// Get returns an empty interface that may be type-asserted to the underlying
// value of type []string.
func (l *strArgList) Get() interface{} {
	return l.Args
}

// metadataYAML stores the contents of one or more YAML file with the following
// top level keys:
// 1. "tags" (list of strings).
// 2. "packages" (list of YAML objects with keys "name" & "version" which are
//    strings).
type metadataYAML struct {
	// Tags is the list of tags read from YAML files with a top level "tags"
	// key.
	Tags []string `yaml:"tags"`
	// Packages is the list of software package entries read from YAML files
	// with a top level "packages" key.
	Packages []metadata.PackageMetadata `yaml:"packages"`

	// tagsLookup maintains a map of tags in the "Tags" field.
	tagsLookup map[string]bool
}

// merge merges the contents of the metadataYaml 'from' into the metadataYAML
// 'm'. This does the following:
// 1. Add every tag that appears in 'from' into 'm' if it doesn't already exist
//    in 'm'.
// 2. Add every package that apppears in 'from' into 'm'. If the list of
//    packages in 'from' have duplicates with the list of packages in 'm', the
//    list of packages in 'm' will contain these duplicates after the merge.
func (m *metadataYAML) merge(from *metadataYAML) error {
	for _, t := range from.Tags {
		if _, ok := m.tagsLookup[t]; ok {
			// This tag has been added already.
			continue
		}
		m.tagsLookup[t] = true
		m.Tags = append(m.Tags, t)
	}
	for _, p := range from.Packages {
		m.Packages = append(m.Packages, p)
	}
	return nil
}

func main() {
	var yamlFiles strArgList
	flag.Var(&yamlFiles, "yamlFile", "Path to an input YAML file to process. Can be specified multiple times to process more than one file.")
	flag.Parse()
	log.Println("Running the YAML Metadata merger.")
	for _, f := range yamlFiles.Args {
		log.Println("-yamlFile", f)
	}
	log.Println("-outFile", *outFile)
	if len(yamlFiles.Args) == 0 {
		log.Fatalf("No input YAML files provided. Use the -yamlFile flag to provide at least 1 YAML file.")
	}
	if *outFile == "" {
		log.Fatalf("-outFile was not specified.")
	}

	result := metadataYAML{tagsLookup: make(map[string]bool)}
	for _, yamlFile := range yamlFiles.Args {
		log.Println("Loading metadata from", yamlFile)
		blob, err := ioutil.ReadFile(yamlFile)
		if err != nil {
			log.Fatalf("Unable to read data from %s: %v", yamlFile, err)
		}
		m := new(metadataYAML)
		if err := yaml.UnmarshalStrict(blob, m); err != nil {
			log.Fatalf("Unable to parse data read from %s as metadata YAML: %v", yamlFile, err)
		}
		if err := result.merge(m); err != nil {
			log.Fatalf("Unable to merge metadata read from %s into a single merged YAML: %v", yamlFile, err)
		}
	}
	log.Printf("Merged YAML has %d tags and %d packages.", len(result.Tags), len(result.Packages))
	blob, err := yaml.Marshal(&result)
	if err != nil {
		log.Fatalf("Unable to generate a merged YAML blob for the output merged YAML file: %v", err)
	}
	if err := ioutil.WriteFile(*outFile, blob, os.FileMode(0644)); err != nil {
		log.Fatalf("Unable to write %d bytes of content to output YAML file %s: %v", len(blob), *outFile, err)
	}
	log.Printf("Successfully generated output %s that merged %d YAML files.", *outFile, len(yamlFiles.Args))
}
