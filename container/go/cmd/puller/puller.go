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
// Unlike regular docker pull, the format this package uses is proprietary.

package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	ospkg "os"
	"strings"
	"time"

	"github.com/pkg/errors"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/cache"

	"github.com/google/go-containerregistry/pkg/v1/remote"
)

var (
	imgName         = flag.String("name", "", "The name location including repo and digest/tag of the docker image to pull and save. Supports fully-qualified tag or digest references.")
	directory       = flag.String("directory", "", "Where to save the images files. If pulling as Docker tarball, please specify the directory to save the tarball. The tarball is named as image.tar.")
	clientConfigDir = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	cachePath       = flag.String("cache", "", "Image's files cache directory.")
	arch            = flag.String("architecture", "", "Image platform's CPU architecture.")
	os              = flag.String("os", "", "Image's operating system, if referring to a multi-platform manifest list. Default linux.")
	osVersion       = flag.String("os-version", "", "Image's operating system version, if referring to a multi-platform manifest list. Input strings are space separated.")
	osFeatures      = flag.String("os-features", "", "Image's operating system features, if referring to a multi-platform manifest list. Input strings are space separated.")
	variant         = flag.String("variant", "", "Image's CPU variant, if referring to a multi-platform manifest list.")
	features        = flag.String("features", "", "Image's CPU features, if referring to a multi-platform manifest list.")
	timeout         = flag.Int("timeout", 600, "Timeout in seconds for the puller. e.g., --timeout=1000 for a 1000 second timeout.")
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

// pull pulls the given image to the given destination directory. A cached
// copy of the image will be loaded from the given cache path if available. If
// the given image name points to a list of images, the given platform will
// be used to select the image to pull.
func pull(imgName, dstPath, cachePath string, platform v1.Platform, transport *http.Transport) error {
	// Get a digest/tag based on the name.
	ref, err := name.ParseReference(imgName)
	if err != nil {
		return errors.Wrapf(err, "parsing tag %q", imgName)
	}

	// Fetch the image with desired cache files and platform specs.
	img, err := remote.Image(ref, remote.WithAuthFromKeychain(authn.DefaultKeychain), remote.WithPlatform(platform), remote.WithTransport(transport))
	if err != nil {
		return errors.Wrapf(err, "reading image %q", ref)
	}
	if cachePath != "" {
		img = cache.Image(img, cache.NewFilesystemCache(cachePath))
	}

	if err := compat.WriteImage(img, dstPath); err != nil {
		return errors.Wrapf(err, "unable to save remote image %v", ref)
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

	// Create a Platform struct with given arguments.
	platform := v1.Platform{
		Architecture: *arch,
		OS:           *os,
		OSVersion:    *osVersion,
		OSFeatures:   strings.Fields(*osFeatures),
		Variant:      *variant,
		Features:     strings.Fields(*features),
	}

	dur := time.Duration(*timeout) * time.Second
	t := &http.Transport{
		Dial: func(network, addr string) (net.Conn, error) {
			d := net.Dialer{Timeout: dur, KeepAlive: dur}
			conn, err := d.Dial(network, addr)
			if err != nil {
				return nil, err
			}
			if err := conn.SetDeadline(time.Now().Add(dur)); err != nil {
				return nil, errors.Wrap(err, "unable to set deadline for HTTP connections")
			}
			return conn, nil
		},
		TLSHandshakeTimeout:   dur,
		IdleConnTimeout:       dur,
		ResponseHeaderTimeout: dur,
		ExpectContinueTimeout: dur,
		Proxy:                 http.ProxyFromEnvironment,
	}

	if err := pull(*imgName, *directory, *cachePath, platform, t); err != nil {
		log.Fatalf("Image pull was unsuccessful: %v", err)
	}

	log.Printf("Successfully pulled image %q into %q", *imgName, *directory)
}
