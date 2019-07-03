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
// with container_import rule.

package compat

import (
	ospkg "os"
	"path"
	"strconv"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/pkg/errors"
)

// Where the pulled OCI image artifacts are stored in.
const artifactsDir = "image-oci"

// Where the alias to the correct config.json and layers.tar.gz are found
const symlinksDir = "image"

// Extension for layers and config files that are made symlinks
const targz = ".tar.gz"
const configExt = "config.json"

// generateSym creates predictable symbolic links to the config.json and layer .tar.gz files
// so that they may be easily consumed by container_import targets.
// The dstPath is the top level directory in which the puller will create symlinks inside an image/ directory
// pointing to actual pulled OCI image artifacts in image-oci/ directory.
func generateSymlinks(img v1.Image, dstPath string) error {
	targetDir := path.Join(dstPath, artifactsDir, "blobs/sha256")
	symlinkDir := path.Join(dstPath, symlinksDir)

	// symlink for config.json, which is an expected attribute of container_import
	// so we must rename the OCI layout's config file (named as the sha256 digest) under blobs/sha256
	var config v1.Hash
	var err error
	if config, err = img.ConfigName(); err != nil {
		return errors.Wrapf(err, "failed to get the config file's hash information for image")
	}
	configPath := path.Join(targetDir, config.Hex)
	if _, err = ospkg.Stat(configPath); ospkg.IsNotExist(err) {
		return errors.Wrapf(err, "config file does not exist at %s", configPath)
	}

	dstLink := path.Join(symlinkDir, configExt)
	if _, err := ospkg.Lstat(dstLink); err == nil {
		if err = ospkg.Remove(dstLink); err != nil {
			return errors.Wrapf(err, "failed to remove the file at %s", dstLink)
		}
	}
	if err := ospkg.Symlink(configPath, dstLink); err != nil {
		return errors.Wrapf(err, "failed to create symbolic link from %s to config.json at %s", dstLink, configPath)
	}

	// symlink for the layers.
	layers, err := img.Layers()
	if err != nil {
		return errors.Wrapf(err, "failed to initialize layers array, image does not have any layers")
	}
	if layers, err = img.Layers(); err != nil {
		return errors.Wrapf(err, "failed to get the layers for image")
	}
	var layerPath string
	for i, layer := range layers {
		layerDigest, err := layer.Digest()
		if err != nil {
			return errors.Wrapf(err, "failed to fetch the layer's digest")
		}

		layerPath = path.Join(targetDir, layerDigest.Hex)
		if _, err = ospkg.Stat(layerPath); ospkg.IsNotExist(err) {
			return errors.Wrapf(err, "layer file does not exist at %s", layerPath)
		}

		out := strconv.Itoa(i) + targz
		dstLink = path.Join(symlinkDir, out)
		if _, err := ospkg.Lstat(dstLink); err == nil {
			if err = ospkg.Remove(dstLink); err != nil {
				return errors.Wrapf(err, "failed to remove the file at %s", dstLink)
			}
		}
		if err = ospkg.Symlink(layerPath, dstLink); err != nil {
			return errors.Wrapf(err, "failed to create symbolic link from %s to layer at %s", dstLink, layerPath)
		}
	}

	return nil
}
