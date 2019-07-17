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
	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/pkg/errors"
)

var (
	dst             = flag.String("dst", "", "The destination location including repo and digest/tag of the docker image to push. Supports fully-qualified tag or digest references.")
	src             = flag.String("src", "", "Path to the manifest.json when -format is legacy, path to the index.json when -format is oci or path to the image .tar file when -format is docker.")
	format          = flag.String("format", "", "The format of the source image, (oci, legacy, or docker). The docker format should be a tarball of the image as generated by docker save.")
	clientConfigDir = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
)

const manifestPath = "manifest.json"

func main() {
	flag.Parse()
	log.Println("Running the Image Pusher to push images to a Docker Registry...")

	if *dst == "" {
		log.Fatalln("Required option -dst was not specified.")
	}
	if *src == "" {
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
	if *format == "legacy" && filepath.Base(*src) != "config.json" {
		log.Fatalf("Invalid value for argument -src for -format=legacy, got %q, want path to config.json", *src)
	}
	if *format == "oci" && filepath.Base(*src) != "index.json" {
		log.Fatalf("Invalid value for argument -src for -format=oci, got %q, want path to index.json", *src)
	}
	if *format == "oci" || *format == "legacy" {
		imgSrc = filepath.Dir(*src)
		log.Printf("Determined image source path to be %q based on -format=%q, -src=%q.", imgSrc, *format, *src)
	}
	if *format == "docker" {
		imgSrc = *src
	}
	if *format == "legacy" {
		_, err := compat.GenerateManifest(imgSrc, imgSrc+manifestPath)
		if err != nil {
			log.Fatalf("error generating %s from %s: %v", manifestPath, imgSrc, err)
		}
	}

	img, err := readImage(imgSrc, *format)
	if err != nil {
		log.Fatalf("error reading from %s: %v", imgSrc, err)
	}

	if err := push(*dst, img); err != nil {
		log.Fatalf("error pushing image to %s: %v", *dst, err)
	}

	log.Printf("Successfully pushed %s image from %s to %s", *format, imgSrc, *dst)
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

// readImage returns a v1.Image after reading an legacy layout, an OCI layout or a Docker tarball from src.
func readImage(src, format string) (v1.Image, error) {
	if format == "oci" {
		return oci.Read(src)
	}
	if format == "legacy" {
		return compat.Read(src)
	}
	if format == "docker" {
		return tarball.ImageFromPath(src, nil)
	}

	return nil, errors.Errorf("unknown image format %q", format)
}
