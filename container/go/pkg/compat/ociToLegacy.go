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
	"io/ioutil"
	"log"
	"os"
	ospkg "os"
	"path"
	"strconv"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/layout"
	"github.com/pkg/errors"
)

// Extension for layers and config files that are made symlinks
const compressedLayerExt = ".tar.gz"
const legacyConfigFile = "config.json"
const legacyManifestFile = "manifest.json"

// generateSymlinks safely generates a symbolic link at dst pointing to src.
func generateSymlinks(src, dst string) error {
	if _, err := ospkg.Stat(src); err != nil {
		return errors.Wrapf(err, "source file does not exist at %s", src)
	}

	if _, err := ospkg.Lstat(dst); err == nil {
		if err = ospkg.Remove(dst); err != nil {
			return errors.Wrapf(err, "failed to remove existing file at %s", dst)
		}
	}
	if err := ospkg.Symlink(src, dst); err != nil {
		return errors.Wrapf(err, "failed to create symbolic link from %s to %s", dst, src)
	}

	return nil
}

// LegacyFromOCIImage creates predictable symbolic links to the config.json and layer .tar.gz files
// so that they may be easily consumed by container_import targets.
// The dstPath is the top level directory in which the puller will create symlinks inside an image/ directory
// pointing to actual pulled OCI image artifacts in image-oci/ directory.
func LegacyFromOCIImage(img v1.Image, srcDir, dstDir string) error {
	targetDir := path.Join(srcDir, "blobs/sha256")

	// symlink for config.json, which is an expected attribute of container_import
	// so we must rename the OCI layout's config file (named as the sha256 digest) under blobs/sha256.
	config, err := img.ConfigName()
	if err != nil {
		return errors.Wrap(err, "failed to get the config file's hash information for image")
	}
	configPath := path.Join(targetDir, config.Hex)
	dstLink := path.Join(dstDir, legacyConfigFile)
	if err = generateSymlinks(configPath, dstLink); err != nil {
		return errors.Wrap(err, "failed to generate config.json symlink")
	}

	// symlink for the tarred layers pulled into OCI layout to x.tar.gz, which is an expected
	// attribute of container_import, so we must rename the layer current named after its sha256
	// digest under blobs/sha256.
	layers, err := img.Layers()
	if err != nil {
		return errors.Wrap(err, "unable to get layers from image")
	}
	var layerPath string
	for i, layer := range layers {
		layerDigest, err := layer.Digest()
		if err != nil {
			return errors.Wrap(err, "failed to fetch the layer's digest")
		}

		layerPath = path.Join(targetDir, layerDigest.Hex)
		out := strconv.Itoa(i) + compressedLayerExt
		dstLink = path.Join(dstDir, out)
		if err = generateSymlinks(layerPath, dstLink); err != nil {
			return errors.Wrapf(err, "failed to generate legacy symlink for layer %d with digest %s", i, layerDigest)
		}
	}

	// symlink for the image manifest pulled into OCI layout to .json, so must rename the file from being
	// named after its sha256 digest under blobs/sha256 to manifest.json
	imgIndex, err := layout.ImageIndexFromPath(srcDir)
	if err != nil {
		return errors.Wrapf(err, "unable to open image as index from %s", srcDir)
	}
	manifest, err := imgIndex.IndexManifest()
	if err != nil {
		return errors.Wrap(err, "unable to get manifest from image index")
	}
	if len(manifest.Manifests) != 1 {
		log.Fatalf("Image index read from %s had unexpected number of manifests: got %d, want 1", srcDir, len(manifest.Manifests))
	}
	manifestHex := manifest.Manifests[0].Digest.Hex
	dstLink = path.Join(dstDir, legacyManifestFile)
	manifestPath := path.Join(targetDir, manifestHex)
	if err = generateSymlinks(manifestPath, dstLink); err != nil {
		return errors.Wrapf(err, "failed to generate %s symlink", legacyManifestFile)
	}

	return nil
}

// WriteDigest writes the sha256 digest of the manifest of the given image to the file given by dst.
func WriteDigest(image v1.Image, dst string) error {
	digest, err := image.Digest()
	if err != nil {
		return errors.Wrap(err, "error getting image digest")
	}

	rawDigest := []byte(digest.Algorithm + ":" + digest.Hex)

	if err = ioutil.WriteFile(dst, rawDigest, os.ModePerm); err != nil {
		return errors.Wrapf(err, "unable to write digest file to %s", dst)
	}

	return nil
}
