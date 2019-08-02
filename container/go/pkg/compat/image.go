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
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"sync"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

// legacyImage is the image in legacy intermediate format. Implements v1.Image, and its implementation is very similar to layout.layoutImage.
type legacyImage struct {
	// path is the path to the directory containing the legacy image.
	path string
	// digest is the sha256 hash for this image.
	digest v1.Hash
	// config is the path to the image config.
	configPath string
	// layersPath is the paths to the layers for this image.
	layersPath []string
	// manifestLock protects rawManifest.
	manifestLock sync.Mutex
	// rawManifest is the raw bytes of manifest.json file.
	rawManifest []byte
}

var _ partial.CompressedImageCore = (*legacyImage)(nil)

// MediaType of this image's manifest from manifest.json.
func (li *legacyImage) MediaType() (types.MediaType, error) {
	manifest, err := li.Manifest()
	if err != nil {
		return "", err
	}

	if manifest.MediaType != types.OCIManifestSchema1 && manifest.MediaType != types.DockerManifestSchema2 {
		return "", fmt.Errorf("unexpected media type for %v: %s", li.digest, manifest.MediaType)
	}

	return manifest.MediaType, nil
}

// Parses manifest.json into Manifest object. Implements WithManifest for partial.Blobset.
func (li *legacyImage) Manifest() (*v1.Manifest, error) {
	return partial.Manifest(li)
}

// RawManifest returns the serialized bytes of manifest.json metadata.
func (li *legacyImage) RawManifest() ([]byte, error) {
	li.manifestLock.Lock()
	defer li.manifestLock.Unlock()

	if li.rawManifest != nil {
		return li.rawManifest, nil
	}

	// Read and store raw manifest.json file from src directory.
	b, err := ioutil.ReadFile(filepath.Join(li.path, manifestFile))
	if err != nil {
		return nil, err
	}

	li.rawManifest = b
	return li.rawManifest, nil
}

// RawConfigFile returns the serialized bytes of config.json metadata.
func (li *legacyImage) RawConfigFile() ([]byte, error) {
	return ioutil.ReadFile(li.configPath)
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
			path:     li.path,
			desc:     manifest.Config,
			filepath: filepath.Join(li.path, "config.json"),
		}), nil
	}

	for i, desc := range manifest.Layers {
		if h == desc.Digest {
			switch desc.MediaType {
			case types.OCILayer, types.DockerLayer:
				return partial.CompressedToLayer(&compressedBlob{
					path:     li.path,
					desc:     desc,
					filepath: li.layersPath[i],
				})
			default:
				// TODO: We assume everything is a compressed blob, but that might not be true.
				// TODO: Handle foreign layers.
				return nil, fmt.Errorf("unexpected media type: %v for layer: %v", desc.MediaType, desc.Digest)
			}
		}
	}

	return nil, fmt.Errorf("could not find layer in image: %s", h)
}

type compressedBlob struct {
	// path of this compressed blob.
	path string
	// desc is the descriptor of this compressed blob.
	desc v1.Descriptor
	// filepath is the file path of this blob at the directory.
	filepath string
}

// The digest of this compressedBlob.
func (b *compressedBlob) Digest() (v1.Hash, error) {
	return b.desc.Digest, nil
}

// Return and open a the layer file at path.
func (b *compressedBlob) Compressed() (io.ReadCloser, error) {
	return os.Open(b.filepath)
}

// The size of this compressedBlob.
func (b *compressedBlob) Size() (int64, error) {
	return b.desc.Size, nil
}

// The media type of this compressedBlob.
func (b *compressedBlob) MediaType() (types.MediaType, error) {
	return b.desc.MediaType, nil
}
