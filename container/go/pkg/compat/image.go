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
// Uses the go-containerregistry API as backend.

package compat

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"sync"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

// This intermediate layout image implements v1.Image, its implementation is very similar to layout.layoutImage.
type layoutImage struct {
	// path is the path of this layout, with helper functions for finding the full directory.
	path Path
	// desc is the descriptor metadata for this image.
	desc v1.Descriptor
	// manifestLock protects rawManifest.
	manifestLock sync.Mutex
	// rawManifest is the raw bytes of manifest.json file.
	rawManifest []byte
}

var _ partial.CompressedImageCore = (*layoutImage)(nil)

// MediaType of this image's manifest.
func (li *layoutImage) MediaType() (types.MediaType, error) {
	return li.desc.MediaType, nil
}

// Parses manifest.json into Manifest object. Implements WithManifest for partial.Blobset.
func (li *layoutImage) Manifest() (*v1.Manifest, error) {
	return partial.Manifest(li)
}

// RawManifest returns the serialized bytes of manifest.json metadata.
func (li *layoutImage) RawManifest() ([]byte, error) {
	li.manifestLock.Lock()
	defer li.manifestLock.Unlock()
	if li.rawManifest != nil {
		return li.rawManifest, nil
	}

	b, err := ioutil.ReadFile(li.path.path("manifest.json"))
	if err != nil {
		return nil, err
	}

	li.rawManifest = b
	return li.rawManifest, nil
}

// RawConfigFile returns the serialized bytes of config.json metadata.
func (li *layoutImage) RawConfigFile() ([]byte, error) {
	return ioutil.ReadFile(li.path.path("config.json"))
}

// LayerByDigest returns a Layer for interacting with a particular layer of
// the image, looking it up by "digest" (the compressed hash).
// We assume the layer files are named in the format of e.g., 000.tar.gz in this path, following the order they appear in manifest.json.
func (li *layoutImage) LayerByDigest(h v1.Hash) (partial.CompressedLayer, error) {
	manifest, err := li.Manifest()
	if err != nil {
		return nil, err
	}

	// The config is a layer in some cases.
	if h == manifest.Config.Digest {
		return partial.CompressedLayer(&compressedBlob{
			path:  li.path,
			desc:  manifest.Config,
			index: -1,
		}), nil
	}

	for i, desc := range manifest.Layers {
		if h == desc.Digest {
			switch desc.MediaType {
			case types.OCILayer, types.DockerLayer:
				return partial.CompressedToLayer(&compressedBlob{
					path: li.path,
					desc: desc,
					// Passed in index to look for the actual gzipped layer file due to intermediate format naming convention.
					index: i,
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
	// path of this compressed blob with helper functions for finding the full directory.
	path Path
	// desc is the descriptor of this compressed blob.
	desc v1.Descriptor
	// index is the order this compressed layer appears in manifest.json, which will be used to identify its filename. Set to be -1 if this is a config layer.
	index int
}

// The digest of this compressedBlob.
func (b *compressedBlob) Digest() (v1.Hash, error) {
	return b.desc.Digest, nil
}

// Return and open a layer file (based on its index, e.g., opens 000.tar.gz for layer with index 0) if this is a layer.
// Return and open the config file if this compressedBlob is for a config.
func (b *compressedBlob) Compressed() (io.ReadCloser, error) {
	if b.index == -1 {
		return os.Open(b.path.path("config.json"))
	}
	return os.Open(b.path.path(layerFilename(b.index)))
}

// The size of this compressedBlob.
func (b *compressedBlob) Size() (int64, error) {
	return b.desc.Size, nil
}

// The media type of this compressedBlob.
func (b *compressedBlob) MediaType() (types.MediaType, error) {
	return b.desc.MediaType, nil
}
