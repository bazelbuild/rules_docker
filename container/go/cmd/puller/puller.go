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
// For the format specification, if the format is:
// 		1. 'docker': image is pulled as tarball and may be used with `docker load -i`.
// 		2. 'oci' (default): image will be pulled as a collection of files in OCI layout to directory.
// 		3. 'both': both formats of image are pulled.
// Unlike regular docker pull, the format this package uses is proprietary.

package main

import (
	"flag"
	"fmt"
	"log"
	ospkg "os"
	"path"
	"strconv"
	"strings"

	"github.com/pkg/errors"

	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/cache"

	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

var (
	imgName         = flag.String("name", "", "The name location including repo and digest/tag of the docker image to pull and save. Supports fully-qualified tag or digest references.")
	directory       = flag.String("directory", "", "Where to save the images files. If pulling as Docker tarball, please specify the directory to save the tarball. The tarball is named as image.tar.")
	format          = flag.String("format", "", "Format to pull image from remote registry: If 'docker', image is pulled as tarball. If 'oci' (default), image will be pulled as a collection of files in OCI layout. Specify 'both' if both formats are needed.")
	clientConfigDir = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	cachePath       = flag.String("cache", "", "Image's files cache directory.")
	arch            = flag.String("architecture", "", "Image platform's CPU architecture.")
	os              = flag.String("os", "", "Image's operating system, if referring to a multi-platform manifest list. Default linux.")
	osVersion       = flag.String("os-version", "", "Image's operating system version, if referring to a multi-platform manifest list. Input strings are space separated.")
	osFeatures      = flag.String("os-features", "", "Image's operating system features, if referring to a multi-platform manifest list. Input strings are space separated.")
	variant         = flag.String("variant", "", "Image's CPU variant, if referring to a multi-platform manifest list.")
	features        = flag.String("features", "", "Image's CPU features, if referring to a multi-platform manifest list.")
)

// Tag applied to images that were pulled by digest. This denotes
// that the image was (probably) not tagged with this, but avoids
// applying the ":latest" tag which might be misleading.
const iWasADigestTag = "i-was-a-digest"

// getTag parses the reference inside the name flag and returns the apt tag.
// WriteToFile requires a tag to write to the tarball, but may have been given a digest,
// in which case we tag the image with :i-was-a-digest instead.
func getTag(ref name.Reference) name.Reference {
	var err error
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
	return tag
}

// NOTE: This function is adapted from https://github.com/google/go-containerregistry/blob/master/pkg/crane/pull.go
// with slight modification to take in a platform argument.
// Pull the image with given <imgName> to destination <dstPath> with optional cache files and required platform specifications.
func pull(imgName, dstPath, format, cachePath string, platform v1.Platform) error {
	// Get a digest/tag based on the name.
	ref, err := name.ParseReference(imgName)
	if err != nil {
		return errors.Wrapf(err, "parsing tag %q", imgName)
	}

	// Fetch the image with desired cache files and platform specs.
	img, err := remote.Image(ref, remote.WithAuthFromKeychain(authn.DefaultKeychain), remote.WithPlatform(platform))
	if err != nil {
		return errors.Wrapf(err, "reading image %q", ref)
	}
	if cachePath != "" {
		img = cache.Image(img, cache.NewFilesystemCache(cachePath))
	}

	// Image file to write to disk, either a tarball, OCI layout, or both.
	ociPath := path.Join(dstPath, compat.OCIImageDir)
	tarPath := path.Join(dstPath, "image")
	switch format {
	case "docker":
		tag := getTag(ref)
		if err := tarball.WriteToFile(path.Join(tarPath, "image.tar"), tag, img); err != nil {
			log.Fatalf("failed to write image tarball to %q: %v", tarPath, err)
		}
	case "both":
		tag := getTag(ref)
		if err := tarball.WriteToFile(path.Join(tarPath, "image.tar"), tag, img); err != nil {
			log.Fatalf("failed to write image tarball to %q: %v", tarPath, err)
		}
		if err := oci.Write(img, ociPath); err != nil {
			log.Fatalf("failed to write image to %q: %v", ociPath, err)
		}
	default:
		if err := oci.Write(img, ociPath); err != nil {
			log.Fatalf("failed to write image to %q: %v", ociPath, err)
		}
	}

	if format != "docker" {
		if err := compat.LegacyFromOCIImage(img, dstPath); err != nil {
			return errors.Wrapf(err, "failed to generate symbolic links to pulled image at %s", dstPath)
		}
	}

	return nil
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
	// to use it to look for the docker client config.
	if *clientConfigDir != "" {
		ospkg.Setenv("DOCKER_CONFIG", *clientConfigDir)
	}

	formatOptions := map[string]bool{
		"oci":    true,
		"docker": true,
		"both":   true,
	}
	if *format != "" && !formatOptions[*format] {
		log.Fatalln("Invalid option -format. Must be one of 'oci', 'docker', or 'both'.")
	}

	// Create a Platform struct with given arguments.
	platform := v1.Platform{
		Architecture: *arch,
		OS:           *os,
		OSVersion:    *osVersion,
		OSFeatures:   strings.Fields(*osFeatures),
		Variant:      *variant,
		Features:     strings.Fields(*features),
	}

	if err := pull(*imgName, *directory, *format, *cachePath, platform); err != nil {
		log.Fatalf("Image pull was unsuccessful: %v", err)
	}

	log.Printf("Successfully pulled image %q into %q", *imgName, *directory)
}
