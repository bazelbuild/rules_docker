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
// This utility works with the new_container_pull and new_container_load targets
// to generate the appropriate pseudo-intermediate format that is compatible
// with the rules_docker container_import rule.

package compat

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

// isCompressed returns if the given media type represents a compressed layer.
func isCompressed(m types.MediaType) bool {
	return m == types.DockerLayer || m == types.OCILayer
}

// writeImageMetadata generates the following files in the given directory
// for the given image:
// directory/
//   config.json   <-- only *.json, the image's config
//   digest        <-- sha256 digest of the image's manifest
//   manifest.json <-- the image's manifest
func writeImageMetadata(img v1.Image, outDir string) error {
	c, err := img.RawConfigFile()
	if err != nil {
		return errors.Wrap(err, "unable to get raw config from image")
	}
	outConfig := path.Join(outDir, "config.json")
	if err := ioutil.WriteFile(outConfig, c, os.ModePerm); err != nil {
		return errors.Wrapf(err, "unable to write image config to %s", outConfig)
	}
	m, err := img.RawManifest()
	if err != nil {
		return errors.Wrap(err, "unable to get raw manifest from image")
	}
	outManifest := path.Join(outDir, "manifest.json")
	if err := ioutil.WriteFile(outManifest, m, os.ModePerm); err != nil {
		return errors.Wrapf(err, "unable to write image manifest to %s", outManifest)
	}
	d, err := img.Digest()
	if err != nil {
		return errors.Wrap(err, "unable to get image digest")
	}
	outDigest := path.Join(outDir, "digest")
	if err := ioutil.WriteFile(outDigest, []byte(d.String()), os.ModePerm); err != nil {
		return errors.Wrapf(err, "unable to write image digest to %s", outDigest)
	}
	return nil
}

// writeImageLayer writes the given image layer with the given index to the
// given directory.
func writeImageLayer(l v1.Layer, idx int, outDir string) error {
	d, err := l.Digest()
	if err != nil {
		return errors.Wrapf(err, "unable to get digest from layer %d", idx)
	}
	outDigestFile := path.Join(outDir, fmt.Sprintf("%03d.sha256", idx))
	if err := ioutil.WriteFile(outDigestFile, []byte(d.Hex), os.ModePerm); err != nil {
		return errors.Wrapf(err, "unable to write the digest of layer %d to %s", idx, outDigestFile)
	}
	m, err := l.MediaType()
	if err != nil {
		return errors.Wrap(err, "unable to get the media type of layer")
	}
	var contents io.ReadCloser
	var outLayerFile string
	if isCompressed(m) {
		contents, err = l.Compressed()
		outLayerFile = path.Join(outDir, fmt.Sprintf("%03d.tar.gz", idx))
	} else {
		contents, err = l.Uncompressed()
		outLayerFile = path.Join(outDir, fmt.Sprintf("%03d.tar", idx))

	}
	if err != nil {
		return errors.Wrapf(err, "unable to get the contents of layer %d", idx)
	}
	defer contents.Close()
	o, err := os.Create(outLayerFile)
	if err != nil {
		return errors.Wrapf(err, "unable to create %s to write layer %d", outLayerFile, idx)
	}
	if _, err := io.Copy(o, contents); err != nil {
		return errors.Wrapf(err, "unable to write the contents of layer %d to %s", idx, outLayerFile)
	}
	return nil
}

// writeImageLayers generates the following files in the given directory
// for the given image:
// directory/
//   001.tar.gz    <-- the first layer's .tar.gz filesystem delta
//   001.sha256    <-- the sha256 of 1.tar.gz without the "sha256:" prefix.
//   ...
//   N.tar.gz      <-- the Nth layer's .tar.gz filesystem delta
//   N.sha256      <-- the sha256 of N.tar.gz without the "sha256:" prefix.
func writeImageLayers(img v1.Image, outDir string) error {
	layers, err := img.Layers()
	if err != nil {
		return errors.Wrap(err, "unable to get layers from image")
	}
	for i, l := range layers {
		if err := writeImageLayer(l, i, outDir); err != nil {
			return errors.Wrap(err, "unable to write image layer")
		}
	}
	return nil
}

// WriteImage writes the given image to the given directory in the efficient
// rules_docker intermediate format:
//   After calling this, the following filesystem will exist:
// directory/
//   config.json   <-- only *.json, the image's config
//   digest        <-- sha256 digest of the image's manifest
//   manifest.json <-- the image's manifest
//   001.tar.gz    <-- the first layer's .tar.gz filesystem delta
//   001.sha256    <-- the sha256 of 1.tar.gz without the "sha256:" prefix.
//   ...
//   N.tar.gz      <-- the Nth layer's .tar.gz filesystem delta
//   N.sha256      <-- the sha256 of N.tar.gz without the "sha256:" prefix.
// We pad layer indices to only 3 digits because of a known ceiling on the number
// of filesystem layers Docker supports.
func WriteImage(img v1.Image, outDir string) error {
	if err := writeImageMetadata(img, outDir); err != nil {
		return errors.Wrap(err, "unable to write image metadata")
	}
	if err := writeImageLayers(img, outDir); err != nil {
		return errors.Wrap(err, "unable to write image layers")
	}
	return nil
}
