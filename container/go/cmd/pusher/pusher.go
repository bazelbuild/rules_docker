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
	ospkg "os"

	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

var (
	dst             = flag.String("dst", "", "The destination location including repo and digest/tag of the docker image to push. Supports fully-qualified tag or digest references.")
	src             = flag.String("src", "", "The path of the source index relative to the execution workspace.")
	format          = flag.String("format", "", "The form to push, OCI or Docker (A tarball).")
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
		ospkg.Setenv("DOCKER_CONFIG", *clientConfigDir)
	}

	var isOCI = true
	if *format != "OCI" {
		isOCI = false
	}

	push(*dst, *src, isOCI)
}

// NOTE: This function is adapted from https://github.com/google/go-containerregistry/blob/master/pkg/crane/push.go
// with modification for option to push OCI layout or Docker tarball format .
// Push the image from <src> to destination <dst> with specified format (OCI or Docker).
func push(dst, src string, isOCI bool) {
	// Read an OCI index or a Docker tarball from src.
	var img v1.Image
	var err error
	if isOCI {
		img, err = oci.Read(src)
		if err != nil {
			log.Fatalf("error reading OCI Layout from path %s: %v", src, err)
		}
	} else {
		img, err = tarball.ImageFromPath(src, nil)
		if err != nil {
			log.Fatalf("error reading Docker Tarball from path %s: %v", src, err)
		}
	}

	// Push the image to dst.
	ref, err := name.ParseReference(dst)
	if err != nil {
		log.Fatalf("parsing tag %q: %v", dst, err)
	}

	if err := remote.Write(ref, img, remote.WithAuthFromKeychain(authn.DefaultKeychain)); err != nil {
		log.Fatal(err)
	}
}
