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
	"io/ioutil"
	"log"
	"os"

	"github.com/ghodss/yaml"
)

var (
	inJSON  = flag.String("in-json", "", "Path to input JSON file that will be converted to YAML.")
	outYAML = flag.String("out-yaml", "", "Path to output YAML file.")
)

func main() {
	flag.Parse()
	if *inJSON == "" {
		log.Fatalf("--in-json is required.")
	}
	if *outYAML == "" {
		log.Fatalf("--out-yaml is required.")
	}

	j, err := ioutil.ReadFile(*inJSON)
	if err != nil {
		log.Fatalf("Unable to read input JSON file %q: %v", *inJSON, err)
	}
	y, err := yaml.JSONToYAML(j)
	if err != nil {
		log.Fatalf("Unable to convert JSON data loaded from %q to YAML: %v", *inJSON, err)
	}
	if err := ioutil.WriteFile(*outYAML, y, os.ModePerm); err != nil {
		log.Fatalf("Unable to write output YAML to %q: %v", *outYAML, err)
	}
}
