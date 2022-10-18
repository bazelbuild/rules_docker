// Copyright 2015 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// ////////////////////////////////////////////////////////////////////
// This binary pushes an image to a Docker Registry.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path"
	"strings"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/remote/transport"
	"github.com/pkg/errors"
)

var (
	dst                 = flag.String("dst", "", "The destination location including repo and digest/tag of the docker image to push. Supports fully-qualified tag or digest references.")
	imgTarball          = flag.String("tarball", "", "Path to the image tarball as generated by docker save. Required if --config was not specified.")
	imgConfig           = flag.String("config", "", "Path to the image config.json. Required if --tarball was not specified.")
	baseManifest        = flag.String("manifest", "", "Path to the manifest of the base image. This should be the very first image in the chain of images and is only really required for windows images with a base image that has foreign layers.")
	format              = flag.String("format", "", "The format of the uploaded image (Docker or OCI).")
	clientConfigDir     = flag.String("client-config-dir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	skipUnchangedDigest = flag.Bool("skip-unchanged-digest", false, "If set to true, will only push images where the digest has changed.")
	layers              utils.ArrayStringFlags
	stampInfoFile       utils.ArrayStringFlags
	insecureRepository  = flag.Bool("insecure-repository", false, "If set to true, the repository is assumed to be insecure (http vs https)")
)

type dockerHeaders struct {
	HTTPHeaders map[string]string `json:"HttpHeaders,omitempty"`
}

// checkClientConfig ensures the given string represents a valid docker client
// config by ensuring:
// 1. It's a valid filesystem path.
// 2. It's a directory.
func checkClientConfig(configDir string) error {
	if configDir == "" {
		return nil
	}
	s, err := os.Stat(configDir)
	if err != nil {
		return errors.Wrapf(err, "unable to stat %q", configDir)
	}
	if !s.IsDir() {
		return errors.Errorf("%q is not a directory", configDir)
	}
	return nil
}

func main() {
	flag.Var(&layers, "layer", "One or more layers with the following comma separated values (Compressed layer tarball, Uncompressed layer tarball, digest file, diff ID file). e.g., --layer layer.tar.gz,layer.tar,<file with digest>,<file with diffID>.")
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

	// If the user provided a client config directory, ensure it's a valid
	// directory and instruct the keychain resolver to use it to look for the
	// docker client config.
	if err := checkClientConfig(*clientConfigDir); err != nil {
		log.Fatalf("Failed to validate the Docker client config dir %q specified via --client-config-dir: %v", *clientConfigDir, err)
	}
	if *clientConfigDir != "" {
		os.Setenv("DOCKER_CONFIG", *clientConfigDir)
	}

	imgParts, err := compat.ImagePartsFromArgs(*imgConfig, *baseManifest, *imgTarball, layers)
	if err != nil {
		log.Fatalf("Unable to determine parts of the image from the specified arguments: %v", err)
	}
	img, err := compat.ReadImage(imgParts)
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

	digest, err := img.Digest()
	if err != nil {
		log.Printf("Failed to digest image: %v", err)
	}

	var opts []name.Option
	if *insecureRepository {
		options = append(options, name.Insecure)
	}

	if err := push(stamped, img, options...); err != nil {
		log.Fatalf("Error pushing image to %s: %v", stamped, err)
	}

	digestStr := ""
	if !strings.Contains(stamped, "@") {
		digestStr = fmt.Sprintf(" - %s@%s", strings.Split(stamped, ":")[0], digest)
	}

	log.Printf("Successfully pushed %s image to %s%s", *format, stamped, digestStr)
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
func push(dst string, img v1.Image, opts ...name.Option) error {
	// Push the image to dst.
	ref, err := name.ParseReference(dst, opts...)
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

	options := []remote.Option{remote.WithAuthFromKeychain(authn.DefaultKeychain)}

	configPath := path.Join(os.Getenv("DOCKER_CONFIG"), "config.json")
	if _, err := os.Stat(configPath); err == nil {
		file, err := os.Open(configPath)
		if err != nil {
			return errors.Wrapf(err, "unable to open docker config")
		}

		var dockerConfig dockerHeaders
		err = json.NewDecoder(file).Decode(&dockerConfig)
		if err != nil {
			return errors.Wrapf(err, "error parsing docker config")
		}

		httpTransportOption := remote.WithTransport(&headerTransport{
			inner:       newTransport(),
			httpHeaders: dockerConfig.HTTPHeaders,
		})

		options = append(options, httpTransportOption)
	}

	if err := remote.Write(ref, img, options...); err != nil {
		return errors.Wrapf(err, "unable to push image to %s", dst)
	}

	return nil
}

// headerTransport sets headers on outgoing requests.
type headerTransport struct {
	httpHeaders map[string]string
	inner       http.RoundTripper
}

// RoundTrip implements http.RoundTripper.
func (ht *headerTransport) RoundTrip(in *http.Request) (*http.Response, error) {
	for k, v := range ht.httpHeaders {
		// ignore "User-Agent" as it gets overwritten
		if http.CanonicalHeaderKey(k) == "User-Agent" {
			continue
		}
		in.Header.Set(k, v)
	}
	return ht.inner.RoundTrip(in)
}

func newTransport() http.RoundTripper {
	tr := http.DefaultTransport.(*http.Transport).Clone()
	// We really only expect to be talking to a couple of hosts during a push.
	// Increasing MaxIdleConnsPerHost should reduce closed connection errors.
	tr.MaxIdleConnsPerHost = tr.MaxIdleConns / 2

	return tr
}
