// Copyright 2017 The Bazel Authors. All rights reserved.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//    http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License/
////////////////////////////////////
//This binary implements the ability to load a docker image, calculate its image manifest sha256 hash and output a digest file.
package main

import (
	"flag"
	"log"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
)

var (
	dst        = flag.String("dst", "", "The destination location of the digest file to write to.")
	imgTarball = flag.String("tarball", "", "Path to the image tarball as generated by docker save. Required if --config was not specified.")
	imgConfig  = flag.String("config", "", "Path to the image config JSON file. Required if --tarball was not specified.")
	format     = flag.String("format", "", "The format of the uploaded image (Docker or OCI).")
	layers     utils.ArrayStringFlags
)

func main() {
	flag.Var(&layers, "layer", "The list of paths to the compressed layers of this docker image, only with --format=Docker.")
	flag.Parse()

	if *dst == "" {
		log.Fatalln("Required option -dst was not specified.")
	}
	if *imgTarball == "" && *imgConfig == "" {
		log.Fatalln("Neither --tarball nor --config was specified.")
	}
	if *imgTarball != "" && *imgConfig != "" {
		log.Fatalf("Both --tarball=%q & --config=%q were specified. Only one of them must be specified.", *imgTarball, *imgConfig)
	}

	img, err := utils.ReadImage(*imgConfig, *imgTarball, layers)
	if err != nil {
		log.Fatalf("Error reading image: %v", err)
	}
	if *format == "OCI" {
		img, err = oci.AsOCIImage(img)
		if err != nil {
			log.Fatalf("Failed to convert image to OCI format: %v", err)
		}
	}

	if err = compat.WriteDigest(img, *dst); err != nil {
		log.Fatalf("Error outputting digest file to %s: %v", *dst, err)
	}
}
