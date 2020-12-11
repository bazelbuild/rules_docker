// Copyright 2016 The Bazel Authors. All rights reserved.
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
// Binary join_layers creates a Docker image tarball from a base image and a
// list of image layers.
package main

import (
	"flag"
	"log"
	"os"
	"strings"

	legacyTarball "github.com/google/go-containerregistry/pkg/legacy/tarball"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/pkg/errors"
)

var (
	outputTarball  = flag.String("output", "", "Path to the output image tarball.")
	tarballFormat  = flag.String("experimental-tarball-format", "legacy", "Which format to use for the image tarball: \"legacy\" (default) | \"compressed\"")
	tags           utils.ArrayStringFlags
	basemanifests  utils.ArrayStringFlags
	layers         utils.ArrayStringFlags
	sourceImages   utils.ArrayStringFlags
	stampInfoFiles utils.ArrayStringFlags
)

// parseTagToFilename converts a list of key=value where 'key' is the name of
// the tagged image and 'value' is the path to a file into a map from key to
// value.
func parseTagToFilename(tags []string, stamper *compat.Stamper) (map[name.Tag]string, error) {
	result := make(map[name.Tag]string)
	for _, t := range tags {
		split := strings.Split(t, "=")
		if len(split) != 2 {
			return nil, errors.Errorf("%q was not specified in the expected key=value format because it split into %q with unexpected number of elements by '=', got %d, want 2", t, split, len(split))
		}
		img, configFile := split[0], split[1]
		stamped := stamper.Stamp(img)
		t, err := name.NewTag(stamped, name.WeakValidation)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to parse stamped image name %q as a fully qualified image reference", stamped)
		}
		result[t] = configFile
	}
	return result, nil
}

// loadImageTarballs returns the images in the given tarballs.
func loadImageTarballs(imageTarballs []string) ([]v1.Image, error) {
	result := []v1.Image{}
	for _, imgTarball := range imageTarballs {
		img, err := tarball.ImageFromPath(imgTarball, nil)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to load image from tarball %s", imgTarball)
		}
		result = append(result, img)
	}
	return result, nil
}

// writeOutput creates a multi-image tarball at the given output path using
// the images defined by the given tag to config & manifest maps with the
// layers defined by the given LayerParts deriving from images in the given
// tarballs.
func writeOutput(outputTarball string, tarballFormat string, tagToConfigs, tagToBaseManifests map[name.Tag]string, imageTarballs []string, layerParts []compat.LayerParts) error {
	tagToImg := make(map[name.Tag]v1.Image)
	images, err := loadImageTarballs(imageTarballs)
	if err != nil {
		return errors.Wrap(err, "unable to load images from the given tarballs")
	}
	for tag, configFile := range tagToConfigs {
		// Manifest file may not have been specified and this is ok as it's
		// only required if the base images has foreign layers.
		manifestFile := tagToBaseManifests[tag]
		parts := compat.ImageParts{
			Config:       configFile,
			BaseManifest: manifestFile,
			Images:       images,
			Layers:       layerParts,
		}
		img, err := compat.ReadImage(parts)
		if err != nil {
			return errors.Wrapf(err, "unable to load image %v corresponding to config %s", tag, configFile)
		}
		tagToImg[tag] = img
	}
	refToImage := make(map[name.Reference]v1.Image, len(tagToImg))
	for i, d := range tagToImg {
		refToImage[i] = d
	}
	o, err := os.Create(outputTarball)
	if err != nil {
		return errors.Wrapf(err, "unable to create image tarball file %q for writing", outputTarball)
	}

	if tarballFormat == "legacy" {
		return legacyTarball.MultiWrite(refToImage, o)
	} else if tarballFormat == "compressed" {
		return tarball.MultiRefWrite(refToImage, o)
	} else {
		// TODO(#1695): Also support OCI layout?
		return errors.Errorf("invalid tarball format: %q", tarballFormat)
	}
}

func main() {
	flag.Var(&tags, "tag", "One or more fully qualified tag names along with the path to the config of the image they tag in tag=path format. e.g., --tag ubuntu=path/to/config1.json --tag gcr.io/blah/debian=path/to/config2.json.")
	flag.Var(&basemanifests, "basemanifest", "One or more fully qualified tag names along with the manifest of the base image in tag=manifest format. e.g., --basemanifest ubuntu=path/to/manifest1.json --basemanifest gcr.io/blah/debian=path/to/manifest2.json.")
	flag.Var(&layers, "layer", "One or more layers with the following comma separated values (Compressed layer tarball, Uncompressed layer tarball, digest file, diff ID file). e.g., --layer layer.tar.gz,layer.tar,<file with digest>,<file with diffID>.")
	flag.Var(&sourceImages, "tarball", "One or more image tarballs for images from which the output image of this binary may derive. e.g., --source_image imag1.tar --source_image image2.tar.")
	flag.Var(&stampInfoFiles, "stamp-info-file", "Path to one or more Bazel stamp info file with key value pairs for substitution. e.g., --stamp-info-file=file1.txt --stamp-info-file=file2.txt.")
	flag.Parse()

	stamper, err := compat.NewStamper(stampInfoFiles)
	if err != nil {
		log.Fatalf("Unable to initialize stamper: %v", err)
	}
	tagToConfig, err := parseTagToFilename(tags, stamper)
	if err != nil {
		log.Fatalf("Unable to process values passed using the flag --tag: %v", err)
	}
	tagToBaseManifest, err := parseTagToFilename(basemanifests, stamper)
	if err != nil {
		log.Fatalf("Unable to process values passed using the flag --manifest: %v", err)
	}
	layerParts := []compat.LayerParts{}
	for _, layerArg := range layers {
		layer, err := compat.LayerPartsFromString(layerArg)
		if err != nil {
			log.Fatalf("Unable to parse %q specified to --layer: %v", layerArg, err)
		}
		layerParts = append(layerParts, layer)
	}
	if err := writeOutput(*outputTarball, *tarballFormat, tagToConfig, tagToBaseManifest, sourceImages, layerParts); err != nil {
		log.Fatalf("Failed to generate output at %s: %v", *outputTarball, err)
	}
}
