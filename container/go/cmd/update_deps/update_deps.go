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
	v1 "github.com/google/go-containerregistry/pkg/v1"
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

{{- if not .MultiArch }}
DIGESTS = {
	# "{{.Debug}}" circa {{.Date}}
	{{- range $arch, $digest := .DebugTags }}
    "debug": "{{ $digest }}",
	{{- end }}
    # "{{.Latest}}" circa {{.Date}}
	{{- range $arch, $digest := .LatestTags }}
    "latest": "{{ $digest }}",
	{{- end }}
}
{{- else }}
DIGESTS = {
	# "{{.Debug}}" circa {{.Date}}
	{{- range $arch, $digest := .DebugTags }}
    "debug_{{ $arch }}": "{{ $digest }}",
	{{- end }}
    # "{{.Latest}}" circa {{.Date}}
	{{- range $arch, $digest := .LatestTags }}
    "latest_{{ $arch }}": "{{ $digest }}",
	{{- end }}
}
{{- end }}
`

var (
	archs      = flag.String("architectures", "", "List of architectures to be considered (comma separated list). Default is amd64 only.")
	repository = flag.String("repository", "", "The repository for which to resolve tags.")
	output     = flag.String("output", "", "The output file to which we write the values.")
)

type Data struct {
	DebugTags, LatestTags map[string]string
	Debug, Latest, Date   string
	MultiArch             bool
}

func main() {
	flag.Parse()

	if *repository == "" {
		log.Fatalln("Required option -repository was not specified.")
	}
	if *output == "" {
		log.Fatalln("Required option -output was not specified.")
	}
	architectures := []string{"amd64"}
	if *archs != "" {
		architectures = strings.Split(*archs, ",")
	}

	latest := *repository + ":latest"
	debug := *repository + ":debug"
	debugDigests := map[string]string{}
	latestDigests := map[string]string{}
	for _, arch := range architectures {
		options := []crane.Option{}
		options = append(options, crane.WithPlatform(&v1.Platform{Architecture: arch, OS: "linux"}))

		latestDigest, err := crane.Digest(latest, options...)
		if err != nil {
			log.Fatalf("Computing digest for %s: %v", latest, err)
		}
		latestDigests[arch] = latestDigest

		debugDigest, err := crane.Digest(debug, options...)
		if err != nil {
			if !strings.Contains(err.Error(), "MANIFEST_UNKNOWN: Failed to fetch") {
				log.Fatalf("Computing digest for %s: %v", debug, err)
			}
			debugDigest = latestDigest
		}
		debugDigests[arch] = debugDigest
	}

	now := time.Now()
	// Jan 2 15:04:05 2006 MST
	date := now.Format("2006-01-02 15:04 -0700")

	t := template.Must(template.New("digestTemplate").Parse(digestTemplate))

	r := Data{
		DebugTags:  debugDigests,
		LatestTags: latestDigests,
		Debug:      debug,
		Latest:     latest,
		Date:       date,
		MultiArch:  (*archs != ""),
	}

	f, err := os.Create(*output)
	if err != nil {
		log.Fatalf("Failed to open file %s: %s", *output, err)
	}
	defer f.Close()

	err = t.Execute(f, r)
	if err != nil {
		log.Fatalf("Executing template: %v", err)
	}
}
