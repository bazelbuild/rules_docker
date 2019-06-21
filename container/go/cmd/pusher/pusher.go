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
	src             = flag.String("src", "", "The path of the source index relative to the execution workspace.")
	format          = flag.String("format", "", "The form to push, oci or docker (A tarball).")
	clientConfigDir = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
)

func main() {
	flag.Parse()
	log.Println("Running the Image Puller to pull images from a Docker Registry...")

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

	img, err := readImage(*src, *format)
	if err != nil {
		log.Fatalln("Error reading from %s: %v", *src, err)
	}

	if err := push(*dst, img); err != nil {
		log.Fatalln("Error pushing image to %s: %v", *dst, err)
	}
}

// NOTE: This function is adapted from https://github.com/google/go-containerregistry/blob/master/pkg/crane/push.go
// with modification for option to push OCI layout or Docker tarball format .
// Push the given image to destination <dst>.
func push(dst string, img v1.Image) error {
	// Push the image to dst.
	ref, err := name.ParseReference(dst)
	if err != nil {
		return errors.Wrapf("parsing tag %q: %v", dst, err)
	}

	if err := remote.Write(ref, img, remote.WithAuthFromKeychain(authn.DefaultKeychain)); err != nil {
		return errors.Wrapf(err)
	}

	return nil
}

// Return a v1.Image after reading an OCI index or a Docker tarball from src.
func readImage(src, format string) (v1.Image, error) {
	if format == "oci" {
		return oci.Read(src)
	}
	if format == "docker" {
		return tarball.ImageFromPath(src, nil)
	}
	return nil, errors.Wrapf("unknown image format %q", format)
}
