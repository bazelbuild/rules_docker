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
	ospkg "os"
	"path"
	"strconv"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/pkg/errors"
)

// Extension for layers and config files that are made symlinks
const targzExt = ".tar.gz"
const configExt = "config.json"

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
	dstLink := path.Join(dstDir, configExt)
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
		out := strconv.Itoa(i) + targzExt
		dstLink = path.Join(dstDir, out)
		if err = generateSymlinks(layerPath, dstLink); err != nil {
			return errors.Wrapf(err, "failed to generate legacy symlink for layer %d with digest %s", i, layerDigest)
		}
	}

	return nil
}
