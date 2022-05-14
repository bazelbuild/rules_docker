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
// This binary implements the ability to load a docker image index, calculate its image manifest sha256 hash and output a digest file.
package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"

	v1 "github.com/google/go-containerregistry/pkg/v1"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
)

type applicationArgs struct {
	Format         string
	OutputFilePath string
	Images         []utils.ImageIndexArgs
}

func parseArgs(argv []string) (*applicationArgs, error) {
	var args applicationArgs

	appName := argv[0]

	fl := flag.NewFlagSet(appName, flag.ContinueOnError)
	fl.StringVar(
		&args.OutputFilePath, "dst", "",
		"The destination location of the digest file to write to.",
	)
	fl.StringVar(
		&args.Format, "format", "",
		"The format of the uploaded image (Docker or OCI).",
	)

	if err := fl.Parse(argv[1:]); err != nil {
		return nil, err
	}

	if args.OutputFilePath == "" {
		return nil, errors.New("required options -dst was not specified")
	}

	if args.Format == "" {
		return nil, errors.New("required options -format was not specified")
	}

	pargs := fl.Args()

	for len(pargs) > 0 {
		var ia utils.ImageIndexArgs

		npargs, err := ia.Parse(appName, pargs)
		if err != nil {
			return nil, err
		}

		args.Images = append(args.Images, ia)

		pargs = npargs
	}

	return &args, nil
}

func main() {
	args, err := parseArgs(os.Args)
	if err != nil {
		if err == flag.ErrHelp {
			os.Exit(0)
		}

		log.Fatalf("Error: %v", err)
	}

	if err := run(args); err != nil {
		log.Fatalf("Error: %v", err)
	}
}

func run(args *applicationArgs) error {
	if len(args.Images) == 0 {
		log.Println("No provided images.")
		return nil
	}

	ii, err := readImageIndex(args)
	if err != nil {
		return fmt.Errorf("read image index: %v", err)
	}

	digest, err := ii.Digest()
	if err != nil {
		return fmt.Errorf("can't get digest of image index: %v", err)
	}

	var content bytes.Buffer
	fmt.Fprintln(&content, digest.String())

	im, err := ii.IndexManifest()
	if err != nil {
		return fmt.Errorf("can't get index manifest: %v", err)
	}

	for _, manifest := range im.Manifests {
		platform := manifest.Platform
		if platform == nil {
			platform = &v1.Platform{
				Architecture: "amd64",
				OS:           "linux",
			}
		}

		os := platform.OS
		if os == "" {
			os = "linux"
		}

		arch := platform.Architecture
		if arch == "" {
			arch = "amd64"
		}

		platformIdent := os + "/" + arch
		if platform.Variant != "" {
			platformIdent += "/" + platform.Variant
		}

		fmt.Fprintf(&content, "%s\t%s\n", platformIdent, manifest.Digest)
	}

	if err := ioutil.WriteFile(args.OutputFilePath, content.Bytes(), os.ModePerm); err != nil {
		return fmt.Errorf("error outputting digest file to %s: %v", args.OutputFilePath, err)
	}

	return nil
}

func readImageIndex(args *applicationArgs) (v1.ImageIndex, error) {
	platforms := make([]v1.Platform, len(args.Images))
	images := make([]v1.Image, len(args.Images))

	for i, imgArgs := range args.Images {
		parts, err := compat.ImagePartsFromArgs(imgArgs.Config, imgArgs.Manifest, imgArgs.Tarball, imgArgs.Layers)
		if err != nil {
			return nil, err
		}

		img, err := compat.ReadImage(parts)
		if err != nil {
			return nil, err
		}

		platforms[i] = v1.Platform{
			OS:           imgArgs.Platform.OS,
			Architecture: imgArgs.Platform.Arch,
			Variant:      imgArgs.Platform.Variant,
		}
		images[i] = img
	}

	ii, err := compat.NewImageIndex(platforms, images)
	if err != nil {
		return nil, err
	}

	if args.Format == "OCI" {
		ii, err = oci.AsOCIImageIndex(ii)
		if err != nil {
			return nil, fmt.Errorf("failed to convert image index to OCI format: %v", err)
		}
	}

	return ii, nil
}
