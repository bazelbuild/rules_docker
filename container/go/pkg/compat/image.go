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
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"sync"

	"github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

// legacyImage is the image in legacy intermediate format. Implements
// partial.CompressedImageCore in go-containerregistry.
type legacyImage struct {
	// config is the path to the image config.
	configPath string
	// layers are the options to locate the layers in this image.
	layers []LayerOpts
	// rawManifestLock protects rawManifest.
	rawManifestLock sync.Mutex
	// rawManifest is the raw bytes of manifest.json file.
	rawManifest []byte
	// manifestLock projects manifest & layerDigestToDiffID.
	manifestLock sync.Mutex
	// manifest is the manifest object
	manifest *v1.Manifest
	// layerDigestToDiffID is a lookup from the digest of a compressed layer
	// to its diff ID which is the digest of the uncompressed layer.
	layerDigestToDiffID map[string]string
}

var _ partial.CompressedImageCore = (*legacyImage)(nil)

// MediaType of this image's manifest from manifest.json.
func (li *legacyImage) MediaType() (types.MediaType, error) {
	manifest, err := li.Manifest()
	if err != nil {
		return "", err
	}

	if manifest.MediaType != types.OCIManifestSchema1 && manifest.MediaType != types.DockerManifestSchema2 {
		return "", fmt.Errorf("unexpected media type %s for image", manifest.MediaType)
	}

	return manifest.MediaType, nil
}

// Manifest returns the manifest for this image, generating it if necessary.
func (li *legacyImage) Manifest() (*v1.Manifest, error) {
	li.manifestLock.Lock()
	defer li.manifestLock.Unlock()

	if li.manifest != nil {
		return li.manifest, nil
	}

	m, d, err := buildManifest(li.configPath, li.layers)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to build a manifest from config %s & corresponding layer files", li.configPath)
	}
	li.manifest = &m
	li.layerDigestToDiffID = d
	return li.manifest, nil
}

// RawManifest returns the serialized bytes of the manifest of this image,
// generating it if necessary.
func (li *legacyImage) RawManifest() ([]byte, error) {
	li.rawManifestLock.Lock()
	defer li.rawManifestLock.Unlock()

	if li.rawManifest != nil {
		return li.rawManifest, nil
	}

	m, err := li.Manifest()
	if err != nil {
		return nil, err
	}
	jsonManifest, err := json.Marshal(m)
	if err != nil {
		return nil, errors.Wrap(err, "unable to serialize manifest object to JSON")
	}
	li.rawManifest = jsonManifest
	return li.rawManifest, nil
}

// RawConfigFile returns the serialized bytes of config.json metadata.
func (li *legacyImage) RawConfigFile() ([]byte, error) {
	return ioutil.ReadFile(li.configPath)
}

// configFile returns the v1.ConfigFile object for this image.
func (li *legacyImage) configFile() (*v1.ConfigFile, error) {
	f, err := os.Open(li.configPath)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to read image config from %s", li.configPath)
	}
	c, err := v1.ParseConfigFile(f)
	if err != nil {
		return nil, errors.Wrapf(err, "unable to parse config JSON data loaded from %s", li.configPath)
	}
	return c, err
}

// LayerByDigest returns a Layer for interacting with a particular layer of the image, looking it up by "digest" (the compressed hash).
// We assume the layer files are named in the format of e.g., 000.tar.gz in this path, following the order they appear in manifest.json.
func (li *legacyImage) LayerByDigest(h v1.Hash) (partial.CompressedLayer, error) {
	manifest, err := li.Manifest()
	if err != nil {
		return nil, err
	}

	// The config is a layer in some cases.
	if h == manifest.Config.Digest {
		return partial.CompressedLayer(&compressedBlob{
			desc: manifest.Config,
			path: li.configPath,
		}), nil
	}

	for i, desc := range manifest.Layers {
		if h == desc.Digest {
			// A v1.Layer object was directly given. Use it as is.
			if li.layers[i].Layer != nil {
				return li.layers[i].Layer, nil
			}
			switch desc.MediaType {
			case types.OCILayer, types.DockerLayer:
				return partial.CompressedToLayer(&compressedBlob{
					desc: desc,
					path: li.layers[i].Path,
				})
			case types.OCIUncompressedLayer, types.DockerUncompressedLayer:
				diffID, ok := li.layerDigestToDiffID[h.Hex]
				if !ok {
					return nil, errors.Errorf("did not find the diff ID for layer with digest %v which can happen if the image was modified after generating the manifest", h)
				}
				return partial.UncompressedToLayer(
					&uncompressedBlob{
						desc:   desc,
						diffID: v1.Hash{Algorithm: h.Algorithm, Hex: diffID},
						path:   li.layers[i].Path,
					})
			case types.DockerForeignLayer:
				return partial.UncompressedToLayer(
					&foreignBlob{
						diffID: v1.Hash{Algorithm: h.Algorithm, Hex: li.layers[i].DiffID},
					})
			default:
				return nil, fmt.Errorf("unexpected media type: %v for layer: %v", desc.MediaType, desc.Digest)
			}
		}
	}

	return nil, fmt.Errorf("could not find layer in image: %s", h)
}

// compressedBlob represents a compressed layer tarball and implements the
// partial.Compressed interface.
type compressedBlob struct {
	// path of this compressed blob.
	//path string
	// desc is the descriptor of this compressed blob.
	desc v1.Descriptor
	// path is the path to the compressed layer tarball.
	path string
}

// The digest of this compressedBlob.
func (b *compressedBlob) Digest() (v1.Hash, error) {
	return b.desc.Digest, nil
}

// Return the opened compressed layer file.
func (b *compressedBlob) Compressed() (io.ReadCloser, error) {
	return os.Open(b.path)
}

// The size of this compressedBlob.
func (b *compressedBlob) Size() (int64, error) {
	return b.desc.Size, nil
}

// The media type of this compressedBlob.
func (b *compressedBlob) MediaType() (types.MediaType, error) {
	return b.desc.MediaType, nil
}

// uncompressedBlob represents a compressed layer tarball and implements the
// partial.Unompressed interface.
type uncompressedBlob struct {
	// desc is the descriptor of this uncompressed blob.
	desc v1.Descriptor
	// diffID is the digest of the uncompressed blob.
	diffID v1.Hash
	// path is the path to the uncompressed layer tarball.
	path string
}

// DiffID is the digest of this uncompressed blob.
func (b *uncompressedBlob) DiffID() (v1.Hash, error) {
	return b.diffID, nil
}

// Return the opened uncompressed layer file.
func (b *uncompressedBlob) Uncompressed() (io.ReadCloser, error) {
	return os.Open(b.path)
}

// The media type of this compressedBlob.
func (b *uncompressedBlob) MediaType() (types.MediaType, error) {
	return b.desc.MediaType, nil
}

// foreignBlob represents a foreign layer usually present in windows images.
// foreignBlob implements the partial.Uncompressed interface which returns the
// digest as the contents.
type foreignBlob struct {
	// diffID is the diffID of this foreign layer.
	diffID v1.Hash
}

// DiffID returns the diffID of this foreign layer.
func (b *foreignBlob) DiffID() (v1.Hash, error) {
	return b.diffID, nil
}

//  Uncompressed returns a blank reader for this foreign layer.
func (b *foreignBlob) Uncompressed() (io.ReadCloser, error) {
	r := bytes.NewReader([]byte{})
	return ioutil.NopCloser(r), nil
}

// The media type of this compressedBlob.
func (b *foreignBlob) MediaType() (types.MediaType, error) {
	return types.DockerForeignLayer, nil
}
