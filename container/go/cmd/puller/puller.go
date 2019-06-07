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
// This binary pulls images from a Docker Registry.
// Unlike regular docker pull, the format this package uses is proprietary.

package main

import (
	"flag"
	"fmt"
	"log"
	ospkg "os"

	// v1 "github.com/google/go-containerregistry/pkg/v1"
	v1 "../../../../../go-containerregistry/pkg/v1"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/cache"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

var (
	imgName         = flag.String("name", "", "The name location including repo and digest/tag of the docker image to pull and save. Supports fully-qualified tag or digest references.")
	directory       = flag.String("directory", "", "Where to save the images files.")
	clientConfigDir = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	cachePath       = flag.String("cache", "", "Image's files cache directory.")
	arch            = flag.String("architecture", "", "Image platform's CPU architecture.")
	os              = flag.String("os", "", "Image's operating system, if referring to a multi-platform manifest list. Default linux.")
	osVersion       = flag.String("os-version", "", "Image's operating system version, if referring to a multi-platform manifest list.")
	osFeatures      = flag.String("os-features", "", "Image's operating system features, if referring to a multi-platform manifest list.")
	variant         = flag.String("variant", "", "Image's CPU variant, if referring to a multi-platform manifest list.")
	features        = flag.String("features", "", "Image's CPU features, if referring to a multi-platform manifest list.")
)

const iWasADigestTag = "i-was-a-digest"

// Pull the image with given <imgName> to destination <dstPath> with optional
// cache files and required platform specifications.
func pull(imgName, dstPath, cachePath string, platform v1.Platform) {
	// Get a digest/tag based on the name
	ref, err := name.ParseReference(imgName)
	if err != nil {
		log.Fatalf("parsing tag %q: %v", imgName, err)
	}
	log.Printf("Pulling %v", ref)

	// Fetch the image with desired cache files and platform specs
	i, err := remote.Image(ref, remote.WithAuthFromKeychain(authn.DefaultKeychain), remote.WithPlatform(platform))
	if err != nil {
		log.Fatalf("reading image %q: %v", ref, err)
	}
	if cachePath != "" {
		i = cache.Image(i, cache.NewFilesystemCache(cachePath))
	}

	// WriteToFile wants a tag to write to the tarball, but we might have
	// been given a digest.
	// If the original ref was a tag, use that. Otherwise, if it was a
	// digest, tag the image with :i-was-a-digest instead.
	tag, ok := ref.(name.Tag)
	if !ok {
		d, ok := ref.(name.Digest)
		if !ok {
			log.Fatal("ref wasn't a tag or digest")
		}
		s := fmt.Sprintf("%s:%s", d.Repository.Name(), iWasADigestTag)
		tag, err = name.NewTag(s)
		if err != nil {
			log.Fatalf("parsing digest as tag (%s): %v", s, err)
		}
	}

	if err := tarball.WriteToFile(dstPath, tag, i); err != nil {
		log.Fatalf("writing image %q: %v", dstPath, err)
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
	// log.Fatalf("here")

	// Create a Platform struct with arguments
	platform := v1.Platform{
		Architecture: *arch,
		OS:           *os,
		OSVersion:    *osVersion,
		OSFeatures:   []string{*osFeatures},
		Variant:      *variant,
		Features:     []string{*features},
	}

	pull(*imgName, *directory, *cachePath, platform)

	log.Printf("Successfully pulled image %q into %q", *imgName, *directory)

}
