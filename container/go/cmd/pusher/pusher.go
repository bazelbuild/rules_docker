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
// This binary pushes an image to a Docker Registry.
package main

import (
	"flag"
	"log"
	"os"
	"path/filepath"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/pkg/errors"
)

var (
	dst             = flag.String("dst", "", "The destination location including repo and digest/tag of the docker image to push. Supports fully-qualified tag or digest references.")
	src             = flag.String("src", "", "Path to the index.json when -format is oci or path to the image .tar file when -format is docker, optional for legacy format.")
	format          = flag.String("format", "", "The format of the source image, (oci, legacy, or docker). The docker format should be a tarball of the image as generated by docker save.")
	clientConfigDir = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	legacyBaseImage = flag.String("legacyBaseImage", "", "Path to a legacy base image in tarball form. Should be specified only when format is legacy.")
	configPath      = flag.String("configPath", "", "Path to the image config. Should be specified only when format is legacy.")
	layers          utils.ArrayStringFlags
	stampInfoFile   utils.ArrayStringFlags
)

const (
	// manifestFile is the filename of image manifest.
	manifestFile = "manifest.json"
	// indexManifestFile is the filename of image manifest config in OCI format.
	indexManifestFile = "index.json"
)

func main() {
	flag.Var(&layers, "layers", "The list of paths to the layers of this docker image, only used for legacy images.")
	flag.Var(&stampInfoFile, "stampInfoFile", "The list of paths to the stamp info files used to substitute supported attribute when a python format placeholder is provivided in dst, e.g., {BUILD_USER}.")
	flag.Parse()
	log.Println("Running the Image Pusher to push images to a Docker Registry...")

	if *dst == "" {
		log.Fatalln("Required option -dst was not specified.")
	}
	if *src == "" && *format != "legacy" {
		log.Fatalln("Required option -src was not specified.")
	}
	if *format == "" {
		log.Fatalln("Required option -format was not specified.")
	}

	// If the user provided a client config directory, instruct the keychain resolver
	// to use it to look for the docker client config.
	if *clientConfigDir != "" {
		os.Setenv("DOCKER_CONFIG", *clientConfigDir)
	}

	// Validates provided format and src path. Check if src is a tarball when pushing a docker image. Trim basename index.json or manifest.json if src is a directory, since we are pushing a OCI/legacy index.
	var imgSrc string
	if *format == "docker" && filepath.Ext(*src) != ".tar" {
		log.Fatalf("Invalid value for argument -src for -format=docker, got %q, want path to tarball file with extension .tar.", *src)
	}
	if *format == "legacy" && *configPath == "" {
		log.Fatalf("Required option -configPath for legacy format image was not specified.")
	}
	if *format == "oci" && filepath.Base(*src) != indexManifestFile {
		log.Fatalf("Invalid value for argument -src for -format=oci, got %q, want path to %s", *src, indexManifestFile)
	}
	if *format == "oci" || *format == "legacy" {
		imgSrc = filepath.Dir(*src)
		log.Printf("Determined image source path to be %q based on -format=%q, -src=%q.", imgSrc, *format, *src)
	}
	if *format == "docker" {
		imgSrc = *src
	}
	if *format != "legacy" && (*legacyBaseImage != "" || *configPath != "" || len(layers) != 0) {
		log.Fatal("-legacyBaseImage, -configPath and -layers should not be specified for format %s.", *format)
	}
	if *format == "legacy" && *legacyBaseImage == "" {
		imgSrc = filepath.Dir(*configPath)
		manifestPath := filepath.Join(imgSrc, manifestFile)

		// TODO (suvanjan): remove generate manifest after createImageConfig/createImageManifest is always producing a manifest (not a mandatory output currently).
		log.Printf("Generating image manifest to %s...", manifestPath)
		_, err := compat.GenerateManifest(manifestPath, *configPath, layers)
		if err != nil {
			log.Fatalf("Error generating %s from %s: %v", manifestFile, *configPath, err)
		}
	}

	img, err := utils.ReadImage(imgSrc, *format, *configPath, *legacyBaseImage, layers)
	if err != nil {
		log.Fatalf("Error reading from %s: %v", imgSrc, err)
	}

	// Infer stamp info if provided and perform substitutions in the provided tag name.
	formattedDst, err := compat.Stamp(*dst, stampInfoFile)
	if err != nil {
		log.Fatalf("Error resolving stamp info to destination %s: %v", *dst, err)
	}
	if formattedDst != *dst {
		log.Printf("Destination %s was resolved to %s based on inferred stamp info.", *dst, formattedDst)
	}

	if err := push(formattedDst, img); err != nil {
		log.Fatalf("Error pushing image to %s: %v", formattedDst, err)
	}

	log.Printf("Successfully pushed %s image from %s to %s", *format, imgSrc, formattedDst)
}

// push pushes the given image to the given destination.
// NOTE: This function is adapted from https://github.com/google/go-containerregistry/blob/master/pkg/crane/push.go
// with modification for option to push OCI layout, legacy layout or Docker tarball format.
// Push the given image to destination <dst>.
func push(dst string, img v1.Image) error {
	// Push the image to dst.
	ref, err := name.ParseReference(dst)
	if err != nil {
		return errors.Wrapf(err, "error parsing %q as an image reference", dst)
	}

	if err := remote.Write(ref, img, remote.WithAuthFromKeychain(authn.DefaultKeychain)); err != nil {
		return errors.Wrapf(err, "unable to push image to %s", dst)
	}

	return nil
}
