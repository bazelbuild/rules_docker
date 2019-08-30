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
package oci

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"

	"github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

// ociLayer extends a v1.Layer pretenting to be a layer in the equivalent OCI
// format.
type ociLayer struct {
	v1.Layer
}

// MediaType returns the media type of the Layer.
func (l *ociLayer) MediaType() (types.MediaType, error) {
	m, err := l.Layer.MediaType()
	if err != nil {
		return "", err
	}
	switch m {
	case types.DockerConfigJSON:
		return types.OCIConfigJSON, nil
	case types.DockerLayer:
		return types.OCILayer, nil
	case types.DockerUncompressedLayer:
		return types.OCIUncompressedLayer, nil
	}
	return "", errors.Errorf("don't know equivalent OCI layer media type for %s", m)
}

// ociImage extends a v1.Image pretending to be an image with an OCI manifest.
type ociImage struct {
	v1.Image
	// layers are the layers in this image formatted as OCI.
	layers []v1.Layer
	// rawManifest are the raw bytes of the OCI manifest of this image.
	rawManifest []byte
	// manifest is the manifest in OCI schema 1 format of this image.
	manifest *v1.Manifest
	// digest is the sha256 digest of the OCI manifest of this image.
	digest v1.Hash
}

// AsOCIImage converts the given v1.Image to the equivalent OCI image using an
// OCI schema 1 manifest.
func AsOCIImage(img v1.Image) (v1.Image, error) {
	result := &ociImage{Image: img}
	layers, err := img.Layers()
	if err != nil {
		return nil, errors.Wrap(err, "unable to get layers from image")
	}
	for _, l := range layers {
		result.layers = append(result.layers, &ociLayer{Layer: l})
	}
	if err = result.buildManifest(); err != nil {
		return nil, errors.Wrap(err, "unable to generate an OCI manifest for image")
	}
	return result, nil
}

// sha256Digest returns the sha256 digest of the given blob of bytes as a hex
// encoded string.
func sha256Digest(blob []byte) string {
	rawDigest := sha256.Sum256(blob)
	return hex.EncodeToString(rawDigest[:])
}

// buildManifest generates a manifest in the OCI schema 1 format for the
// underlying v1.Image.
func (i *ociImage) buildManifest() error {
	rawConfig, err := i.RawConfigFile()
	if err != nil {
		return errors.Wrap(err, "unable to get the raw config of image")
	}
	configDigest, err := i.ConfigName()
	if err != nil {
		return errors.Wrap(err, "unable to get the digest of the image config")
	}
	i.manifest = &v1.Manifest{
		SchemaVersion: 2,
		MediaType:     types.OCIManifestSchema1,
		Config: v1.Descriptor{
			MediaType: types.OCIConfigJSON,
			Size:      int64(len(rawConfig)),
			Digest:    configDigest,
		},
	}
	for _, l := range i.layers {
		m, err := l.MediaType()
		if err != nil {
			return errors.Wrap(err, "unable to get the media type of layer")
		}
		d, err := l.Digest()
		if err != nil {
			return errors.Wrap(err, "unable to get the layer digest")
		}
		size, err := l.Size()
		if err != nil {
			return errors.Wrap(err, "unable to get the layer size")
		}
		i.manifest.Layers = append(i.manifest.Layers, v1.Descriptor{
			MediaType: m,
			Digest:    d,
			Size:      size,
		})
	}
	rawManifest, err := json.Marshal(i.manifest)
	if err != nil {
		return errors.Wrap(err, "unable to encode manifest to JSON")
	}
	i.rawManifest = rawManifest
	i.digest = v1.Hash{
		Algorithm: "sha256",
		Hex:       sha256Digest(i.rawManifest),
	}
	return nil
}

// Layers returns the ordered collection of filesystem layers that comprise this image.
// The order of the list is oldest/base layer first, and most-recent/top layer last.
func (i *ociImage) Layers() ([]v1.Layer, error) {
	return i.layers, nil
}

// MediaType returns the media type of this image's manifest.
func (i *ociImage) MediaType() (types.MediaType, error) {
	return types.OCIManifestSchema1, nil
}

// Digest returns the sha256 of this image's manifest.
func (i *ociImage) Digest() (v1.Hash, error) {
	return i.digest, nil
}

// Manifest returns this image's Manifest object.
func (i *ociImage) Manifest() (*v1.Manifest, error) {
	return i.manifest, nil
}

// RawManifest returns the serialized bytes of Manifest()
func (i *ociImage) RawManifest() ([]byte, error) {
	return i.rawManifest, nil
}

// LayerByDigest returns a Layer for interacting with a particular layer of
// the image, looking it up by "digest" (the compressed hash).
func (i *ociImage) LayerByDigest(h v1.Hash) (v1.Layer, error) {
	for _, l := range i.layers {
		d, err := l.Digest()
		if err != nil {
			return nil, err
		}
		if h == d {
			return l, nil
		}
	}
	return nil, errors.Errorf("did not find a layer with digest %v", h)
}

// LayerByDiffID is an analog to LayerByDigest, looking up by "diff id"
// (the uncompressed hash).
func (i *ociImage) LayerByDiffID(h v1.Hash) (v1.Layer, error) {
	for _, l := range i.layers {
		d, err := l.DiffID()
		if err != nil {
			return nil, err
		}
		if h == d {
			return l, nil
		}
	}
	return nil, errors.Errorf("did not find a layer with diffID %v", h)
}
