/// Copyright 2015 The Bazel Authors. All rights reserved.
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
// Image for intermediate format used in python containerregistry.
// Adopted from go-containerregistry's layout.image implementation with modification to understand rules_docker's legacy intermediate format.
// Uses the go-containerregistry API as backend.

package compat

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"io/ioutil"
	"os"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

// fullLayer implements the v1.Layer interface constructed from all the parts
// that define a Docker layer such that none of the methods implementing the
// v1.Layer interface need to do any computations on the layer contents.
type fullLayer struct {
	// digest is the digest of this layer.
	digest v1.Hash
	// diffID is the diffID of this layer.
	diffID v1.Hash
	// compressedTarball is the path to the compressed tarball of this layer.
	compressedTarball string
	// uncompressedTarball is the path to the uncompressed tarball of this
	// layer.
	uncompressedTarball string
}

// Digest returns the Hash of the compressed layer.
func (l *fullLayer) Digest() (v1.Hash, error) {
	return l.digest, nil
}

// DiffID returns the Hash of the uncompressed layer.
func (l *fullLayer) DiffID() (v1.Hash, error) {
	return l.diffID, nil
}

// Compressed returns an io.ReadCloser for the compressed layer contents.
func (l *fullLayer) Compressed() (io.ReadCloser, error) {
	f, err := os.Open(l.compressedTarball)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to open compressed layer tarball from %s", l.compressedTarball)
	}
	return f, nil
}

// Uncompressed returns an io.ReadCloser for the uncompressed layer contents.
func (l *fullLayer) Uncompressed() (io.ReadCloser, error) {
	f, err := os.Open(l.uncompressedTarball)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to open uncompressed layer tarball from %s", l.uncompressedTarball)
	}
	return f, nil
}

// UncompressedSize returns the size of the uncompressed layer contents.
func (l *fullLayer) UncompressedSize() (int64, error) {
	f, err := os.Stat(l.uncompressedTarball)
	if err != nil {
		return 0, errors.Wrapf(err, "unable to stat %s to determine size of uncompressed layer", l.uncompressedTarball)
	}
	return f.Size(), nil
}

// Size returns the compressed size of the Layer.
func (l *fullLayer) Size() (int64, error) {
	f, err := os.Stat(l.compressedTarball)
	if err != nil {
		return 0, errors.Wrapf(err, "unable to stat %s to determine size of compressed layer", l.compressedTarball)
	}
	return f.Size(), nil
}

// MediaType returns the media type of the Layer.
func (l *fullLayer) MediaType() (types.MediaType, error) {
	return types.DockerLayer, nil
}

// loadHashes loads the sha256 digests for this layer from the given digest and
// diffID files.
func (l *fullLayer) loadHashes(digestFile, diffIDFile string) error {
	digest, err := ioutil.ReadFile(digestFile)
	if err != nil {
		return errors.Wrapf(err, "unable to load layer digest from %s", digestFile)
	}
	l.digest = v1.Hash{Algorithm: "sha256", Hex: string(digest)}
	diffID, err := ioutil.ReadFile(diffIDFile)
	if err != nil {
		return errors.Wrapf(err, "unable to load layer diffID from %s", diffIDFile)
	}
	l.diffID = v1.Hash{Algorithm: "sha256", Hex: string(diffID)}
	return nil
}

// legacyImage is the image in legacy intermediate format. Implements
// partial.CompressedImageCore in go-containerregistry.
type legacyImage struct {
	// configPath is the path to the image config.
	configPath string
	// config is the parsed config of this image.
	config *v1.ConfigFile
	// rawConfig is the raw bytes of the image config.
	rawConfig []byte
	// configDigest is the sha256 digest of the raw image config.
	configDigest v1.Hash
	// layers are the options to locate the layers in this image.
	layers []v1.Layer
	// rawManifest is the blob of bytes representing the manifest of this
	// image.
	rawManifest []byte
	// manifest is the manifest of this image.
	manifest *v1.Manifest
	// digest is the sha256 digest of the image manifest.
	digest v1.Hash
}

// Ensure legacyImage implements the v1.Image interface.
var _ v1.Image = (*legacyImage)(nil)

// genManifest generates the manifest for the given legacy image. This function
// assumes the config, raw config & config digest have already been loaded.
func (li *legacyImage) genManifest() error {
	li.manifest = &v1.Manifest{
		SchemaVersion: 2,
		MediaType:     types.DockerManifestSchema2,
		Config: v1.Descriptor{
			MediaType: types.DockerConfigJSON,
			Size:      int64(len(li.rawConfig)),
			Digest:    li.configDigest,
		},
	}
	for _, l := range li.layers {
		mediaType, err := l.MediaType()
		if err != nil {
			return errors.Wrap(err, "unable to get media type of layer")
		}
		digest, err := l.Digest()
		if err != nil {
			return errors.Wrap(err, "unable to get digest of layer")
		}
		size, err := l.Size()
		if err != nil {
			return errors.Wrap(err, "unable to get size of layer")
		}
		var urls []string
		if fl, ok := l.(*foreignLayer); ok {
			// The size returned by the Size method on foreign layers is always
			// zero. But the implementation has a private variable with the real
			// size which we need to report in the manifest.
			size = fl.size
			urls = fl.urls
		}
		li.manifest.Layers = append(li.manifest.Layers, v1.Descriptor{
			MediaType: mediaType,
			Digest:    digest,
			Size:      size,
			URLs:      urls,
		})
	}
	manifestBlob, err := json.Marshal(li.manifest)
	if err != nil {
		return errors.Wrap(err, "unable to encode generate manifest to JSON")
	}
	li.rawManifest = manifestBlob
	li.digest = v1.Hash{
		Algorithm: "sha256",
		Hex:       sha256Blob(li.rawManifest),
	}
	return nil
}

// sha256Blob returns the sha256 hex digest of the given blob of bytes.
func sha256Blob(blob []byte) string {
	digestBlob := sha256.Sum256(blob)
	return hex.EncodeToString(digestBlob[:])
}

// init initializes the given legacyImage which includes:
// 1. Generating the manifest.
// 2. Generating the config & manifest digests.
func (li *legacyImage) init() error {
	configBlob, err := ioutil.ReadFile(li.configPath)
	if err != nil {
		return errors.Wrapf(err, "unable to load image config from %s", li.configPath)
	}
	li.rawConfig = configBlob
	config, err := v1.ParseConfigFile(bytes.NewBuffer(li.rawConfig))
	if err != nil {
		return errors.Wrapf(err, "unable to parse config loaded from %s", li.configPath)
	}
	li.config = config
	li.configDigest = v1.Hash{
		Algorithm: "sha256",
		Hex:       sha256Blob(li.rawConfig),
	}
	if err := li.genManifest(); err != nil {
		return errors.Wrap(err, "unable to generate image manifest")
	}
	return nil
}

// Layers returns the ordered collection of filesystem layers that comprise this
// image. The order of the list is oldest/base layer first, and most-recent/top
// layer last.
func (li *legacyImage) Layers() ([]v1.Layer, error) {
	return li.layers, nil
}

// MediaType of this image's manifest from manifest.json.
func (li *legacyImage) MediaType() (types.MediaType, error) {
	return li.manifest.MediaType, nil
}

// Manifest returns the manifest of this image.
func (li *legacyImage) Manifest() (*v1.Manifest, error) {
	return li.manifest, nil
}

// RawManifest returns the serialized bytes of the manifest of this image,
// generating it if necessary.
func (li *legacyImage) RawManifest() ([]byte, error) {
	return li.rawManifest, nil
}

// Size returns the size of the raw manifest.
func (li *legacyImage) Size() (int64, error) {
	return int64(len(li.rawManifest)), nil
}

// RawConfigFile returns the serialized bytes of config.json metadata.
func (li *legacyImage) RawConfigFile() ([]byte, error) {
	return li.rawConfig, nil
}

// ConfigFile returns the v1.ConfigFile object for this image.
func (li *legacyImage) ConfigFile() (*v1.ConfigFile, error) {
	return li.config, nil
}

// Digest returns the sha256 of this image's manifest.
func (li *legacyImage) Digest() (v1.Hash, error) {
	return li.digest, nil
}

// ConfigName returns the hash of the image's config file.
func (li *legacyImage) ConfigName() (v1.Hash, error) {
	return li.configDigest, nil
}

// LayerByDigest returns the layer with the given digest.
func (li *legacyImage) LayerByDigest(h v1.Hash) (v1.Layer, error) {
	for i, l := range li.manifest.Layers {
		if h == l.Digest {
			return li.layers[i], nil
		}
	}
	return nil, errors.Errorf("did not find a layer with digest %v in image", h)
}

// LayerByDigest returns the layer with the given diffID.
func (li *legacyImage) LayerByDiffID(h v1.Hash) (v1.Layer, error) {
	for i, diffID := range li.config.RootFS.DiffIDs {
		if h == diffID {
			return li.layers[i], nil
		}
	}
	return nil, errors.Errorf("did not find a layer with diffID %v in image", h)
}
