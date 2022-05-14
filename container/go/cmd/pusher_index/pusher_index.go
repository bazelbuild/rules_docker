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
// This binary pushes an image index containing multi platform images to a Docker Registry.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
)

type applicationArgs struct {
	ClientConfigDir     string
	StampInfoFiles      []string
	Name                string
	Format              string
	SkipUnchangedDigest bool
	InsecureRepository  bool
	Images              []utils.ImageIndexArgs
}

func parseArgs(argv []string) (*applicationArgs, error) {
	var args applicationArgs

	appName := argv[0]

	fl := flag.NewFlagSet(appName, flag.ContinueOnError)
	fl.StringVar(
		&args.ClientConfigDir, "client-config-dir", "",
		"The path to the directory where the client configuration files are located. Overrides the value from DOCKER_CONFIG.",
	)
	fl.Var(
		(*utils.ArrayStringFlags)(&args.StampInfoFiles), "stamp-info-file",
		"The list of paths to the stamp info files used to substitute supported attribute when a python format placeholder is provided in dst, e.g., {BUILD_USER}.",
	)
	fl.StringVar(
		&args.Name, "dst", "",
		"The destination location including repo and digest/tag of the docker image to push. Supports fully-qualified tag or digest references.",
	)
	fl.StringVar(
		&args.Format, "format", "",
		"The format of the uploaded image (Docker or OCI).",
	)
	fl.BoolVar(
		&args.SkipUnchangedDigest, "skip-unchanged-digest", false,
		"(deprecated, this flag has none action)",
	)
	fl.BoolVar(
		&args.InsecureRepository, "insecure-repository", false,
		"If set to true, the repository is assumed to be insecure (http vs https)",
	)

	if err := fl.Parse(argv[1:]); err != nil {
		return nil, err
	}

	if args.Name == "" {
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
	appName := filepath.Base(os.Args[0])

	args, err := parseArgs(os.Args)
	if err != nil {
		if err == flag.ErrHelp {
			os.Exit(0)
		}

		log.Fatalf("Error: %v", err)
	}

	if err := run(context.Background(), appName, args); err != nil {
		log.Fatalf("Error: %v", err)
	}
}

func run(ctx context.Context, appName string, args *applicationArgs) error {
	if err := utils.InitializeDockerConfig(args.ClientConfigDir); err != nil {
		return err
	}

	stamper, err := compat.NewStamper(args.StampInfoFiles)
	if err != nil {
		return fmt.Errorf("failed to initialize the stamper: %v", err)
	}

	dst := stamper.Stamp(args.Name)

	var opts []name.Option
	if args.InsecureRepository {
		opts = append(opts, name.Insecure)
	}

	ref, err := name.ParseReference(dst, opts...)
	if err != nil {
		return fmt.Errorf("error parsing %q as an image reference: %v", dst, err)
	}

	if len(args.Images) == 0 {
		log.Println("No provided images.")
		return nil
	}

	ii, err := readImageIndex(args)
	if err != nil {
		return err
	}

	digest, err := ii.Digest()
	if err != nil {
		return fmt.Errorf("can't get digest of image index: %v", err)
	}

	remoteOptions, err := utils.ComputeRemoteWriteOptions(ctx, appName)
	if err != nil {
		return err
	}

	if err := remote.WriteIndex(ref, ii, remoteOptions...); err != nil {
		return fmt.Errorf("can't push image index: %v", err)
	}

	log.Printf(
		"Successfully pushed Docker image index to %s - %s@%s",
		ref, ref.Context().Name(), digest,
	)

	return nil
}

func readImageIndex(args *applicationArgs) (v1.ImageIndex, error) {
	platforms := make([]v1.Platform, len(args.Images))
	images := make([]v1.Image, len(args.Images))

	for idx, imgArgs := range args.Images {
		parts, err := compat.ImagePartsFromArgs(imgArgs.Config, imgArgs.Manifest, imgArgs.Tarball, imgArgs.Layers)
		if err != nil {
			return nil, err
		}

		img, err := compat.ReadImage(parts)
		if err != nil {
			return nil, err
		}

		platforms[idx] = v1.Platform{
			OS:           imgArgs.Platform.OS,
			Architecture: imgArgs.Platform.Arch,
			Variant:      imgArgs.Platform.Variant,
		}
		images[idx] = img
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
