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
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/remote/transport"
	"github.com/pkg/errors"
)

var (
	dst                 = flag.String("dst", "", "The destination location including repo and digest/tag of the docker image to push. Supports fully-qualified tag or digest references.")
	imgTarball          = flag.String("tarball", "", "Path to the image tarball as generated by docker save. Only compatible with --format=Docker.")
	imgConfig           = flag.String("config", "", "Path to the image config.json. Required when --format is Docker.")
	format              = flag.String("format", "", "The format of the uploaded image (Docker or OCI).")
	clientConfigDir     = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	skipUnchangedDigest = flag.Bool("skip-unchanged-digest", false, "If set to true, will only push images where the digest has changed.")
	layers              utils.ArrayStringFlags
	stampInfoFile       utils.ArrayStringFlags
)

func main() {
	flag.Var(&layers, "layer", "The list of paths to the layers of this docker image, only used for legacy images.")
	flag.Var(&stampInfoFile, "stamp-info-file", "The list of paths to the stamp info files used to substitute supported attribute when a python format placeholder is provivided in dst, e.g., {BUILD_USER}.")
	flag.Parse()

	if *dst == "" {
		log.Fatalln("Required option -dst was not specified.")
	}
	if *format == "" {
		log.Fatalln("Required option -format was not specified.")
	}
	if *imgTarball == "" && *imgConfig == "" {
		log.Fatalln("Neither --tarball nor --config was specified.")
	}
	if *imgTarball != "" && *imgConfig != "" {
		log.Fatalf("Both --tarball=%q & --config=%q were specified. Only one of them must be specified.", *imgTarball, *imgConfig)
	}

	// If the user provided a client config directory, instruct the keychain resolver
	// to use it to look for the docker client config.
	if *clientConfigDir != "" {
		os.Setenv("DOCKER_CONFIG", *clientConfigDir)
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

	stamper, err := compat.NewStamper(stampInfoFile)
	if err != nil {
		log.Fatalf("Failed to initialize the stamper: %v", err)
	}

	// Infer stamp info if provided and perform substitutions in the provided tag name.
	stamped := stamper.Stamp(*dst)
	if stamped != *dst {
		log.Printf("Destination %s was resolved to %s after stamping.", *dst, stamped)
	}

	if err := push(stamped, img); err != nil {
		log.Fatalf("Error pushing image to %s: %v", stamped, err)
	}

	log.Printf("Successfully pushed %s image to %s", *format, stamped)
}

// digestExists checks whether an image's digest exists in a repository.
func digestExists(dst string, img v1.Image) (bool, error) {
	digest, err := img.Digest()
	if err != nil {
		return false, errors.Wrapf(err, "unable to get local image digest")
	}
	digestRef, err := name.NewDigest(fmt.Sprintf("%s@%s", dst, digest))
	if err != nil {
		return false, errors.Wrapf(err, "couldn't create ref from digest")
	}
	remoteImg, err := remote.Image(digestRef, remote.WithAuthFromKeychain(authn.DefaultKeychain))
	if err != nil {
		if strings.HasPrefix(err.Error(), string(transport.ManifestUnknownErrorCode)) {
			// no manifest matching the digest
			return false, nil
		}
		return false, errors.Wrapf(err, "unable to get remote image")
	}
	return remoteImg != nil, nil
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

	if *skipUnchangedDigest {
		exists, err := digestExists(dst, img)
		if err != nil {
			log.Printf("Error checking if digest already exists %v. Still pushing", err)
		}
		if exists {
			log.Print("Skipping push of unchanged digest")
			return nil
		}
	}

	if err := remote.Write(ref, img, remote.WithAuthFromKeychain(authn.DefaultKeychain)); err != nil {
		return errors.Wrapf(err, "unable to push image to %s", dst)
	}

	return nil
}
