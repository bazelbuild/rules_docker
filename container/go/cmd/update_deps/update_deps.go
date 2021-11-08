// Copyright 2015 The Bazel Authors. All rights reserved.
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
//////////////////////////////////////////////////////////////////////
// Synthesize a .bzl file containing the digests for a given repository.

package main

import (
	"flag"
	"log"
	"os"
	"strings"
	"text/template"
	"time"

	"github.com/google/go-containerregistry/pkg/crane"
	"github.com/google/go-containerregistry/pkg/v1"
)

const digestTemplate = `# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
""" Generated file with dependencies for language rule."""

# !!!! THIS IS A GENERATED FILE TO NOT EDIT IT BY HAND !!!!
#
# To regenerate this file, run ./update_deps.sh from the root of the
# git repository.

DIGESTS = {
    # "{{.Debug}}" circa {{.Date}}
    "debug": "{{.DebugTag}}",
    # "{{.Latest}}" circa {{.Date}}
    "latest": "{{.LatestTag}}",
}
`

var (
	repository = flag.String("repository", "", "The repository for which to resolve tags.")
	output     = flag.String("output", "", "The output file to which we write the values.")
)

type Data struct {
	DebugTag, LatestTag, Debug, Latest, Date string
}

func main() {
	flag.Parse()

	if *repository == "" {
		log.Fatalln("Required option -repository was not specified.")
	}
	if *output == "" {
		log.Fatalln("Required option -output was not specified.")
	}
	options := []crane.Option{}
	options = append(options, crane.WithPlatform(&v1.Platform{Architecture: "amd64", OS: "linux"}))

	latest := *repository + ":latest"
	latestDigest, err := crane.Digest(latest, options...)
	if err != nil {
		log.Fatalf("Computing digest for %s: %v", latest, err)
	}

	debug := *repository + ":debug"
	debugDigest, err := crane.Digest(debug, options...)
	if err != nil {
		if !strings.Contains(err.Error(), "MANIFEST_UNKNOWN: Failed to fetch") {
			log.Fatalf("Computing digest for %s: %v", debug, err)
		}
		debugDigest = latestDigest
	}

	now := time.Now()
	// Jan 2 15:04:05 2006 MST
	date := now.Format("2006-01-02 15:04 -0700")

	t := template.Must(template.New("digestTemplate").Parse(digestTemplate))

	r := Data{
		DebugTag:  debugDigest,
		LatestTag: latestDigest,
		Debug:     debug,
		Latest:    latest,
		Date:      date,
	}

	f, err := os.Create(*output)
	if err != nil {
		log.Fatalf("Failed to open file %s: %s", *output, err)
	}
	defer f.Close()

	err = t.Execute(f, r)
	if err != nil {
		log.Fatalf("Executing template:", err)
	}
}
