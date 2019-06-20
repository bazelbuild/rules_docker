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

	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/remote"
)

var (
	dst = flag.String("dst", "", "The destination location including repo and digest/tag of the docker image to push. Supports fully-qualified tag or digest references.")
	src = flag.String("src", "", "The path of the source index relative to the execution workspace.")
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

	push(*dst, *src)
}

func push(dst, src string) {
	log.Println("src:" + src)
	log.Println("dst:" + dst)
	img, err := oci.Read(src)
	if err != nil {
		log.Fatalf("error reading from path: %v", err)
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
