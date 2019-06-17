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
// This binary pulls images from a Docker Registry using the go-containerregistry as backend.
// Unlike regular docker pull, the format this package uses is proprietary.

package main

import (
	"flag"
	"log"
	ospkg "os"
	"strings"

	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	v1 "github.com/google/go-containerregistry/pkg/v1"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/remote"
)

var (
	imgName         = flag.String("name", "", "The name location including repo and digest/tag of the docker image to pull and save. Supports fully-qualified tag or digest references.")
	directory       = flag.String("directory", "", "Where to save the images files.")
	clientConfigDir = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	arch            = flag.String("architecture", "", "Image platform's CPU architecture.")
	os              = flag.String("os", "", "Image's operating system, if referring to a multi-platform manifest list. Default linux.")
	osVersion       = flag.String("os-version", "", "Image's operating system version, if referring to a multi-platform manifest list.")
	osFeatures      = flag.String("os-features", "", "Image's operating system features, if referring to a multi-platform manifest list.")
	variant         = flag.String("variant", "", "Image's CPU variant, if referring to a multi-platform manifest list.")
	features        = flag.String("features", "", "Image's CPU features, if referring to a multi-platform manifest list.")
)

// Tag applied to images that were pulled by digest. This denotes that the
// image was (probably) never tagged with this, but lets us avoid applying the
// ":latest" tag which might be misleading.
const iWasADigestTag = "i-was-a-digest"

// NOTE: This function is adapted from https://github.com/google/go-containerregistry/blob/master/pkg/crane/pull.go
// with slight modification to take in a platform argument.
// Pull the image with given <imgName> to destination <dstPath> with optional
// cache files and required platform specifications.
func pull(imgName, dstPath string, platform v1.Platform) {
	// Get a digest/tag based on the name.
	ref, err := name.ParseReference(imgName)
	if err != nil {
		log.Fatalf("parsing tag %q: %v", imgName, err)
	}
	log.Printf("Pulling %v", ref)

	// Fetch the image with desired cache files and platform specs.
	img, err := remote.Image(ref, remote.WithAuthFromKeychain(authn.DefaultKeychain), remote.WithPlatform(platform))
	if err != nil {
		log.Fatalf("reading image %q: %v", ref, err)
	}

	// // Image file to write to disk.
	if err := oci.Write(img, dstPath); err != nil {
		log.Fatalf("failed to write image to %q: %v", dstPath, err)
	}
}

func main() {
	flag.Parse()
	log.Println("Running the Image Puller to pull images from a Docker Registry...")

	if *imgName == "" {
		log.Fatalln("Required option -name was not specified.")
	}
	if *directory == "" {
		log.Fatalln("Required option -directory was not specified.")
	}

	// If the user provided a client config directory, instruct the keychain resolver
	// to use it to look for the docker client config
	if *clientConfigDir != "" {
		ospkg.Setenv("DOCKER_CONFIG", *clientConfigDir)
	}

	// Create a Platform struct with arguments
	platform := v1.Platform{
		Architecture: *arch,
		OS:           *os,
		OSVersion:    *osVersion,
		OSFeatures:   strings.Fields(*osFeatures),
		Variant:      *variant,
		Features:     strings.Fields(*features),
	}

	pull(*imgName, *directory, platform)

	log.Printf("Successfully pulled image %q into %q", *imgName, *directory)
}
