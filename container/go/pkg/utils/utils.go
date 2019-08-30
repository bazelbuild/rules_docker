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
package utils

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"strings"

	"github.com/google/go-containerregistry/pkg/v1/tarball"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

// ArrayStringFlags are defined for string flags that may have multiple values.
type ArrayStringFlags []string

// Returns the concatenated string representation of the array of flags.
func (f *ArrayStringFlags) String() string {
	return fmt.Sprintf("%v", *f)
}

// Get returns an empty interface that may be type-asserted to the underlying
// value of type bool, string, etc.
func (f *ArrayStringFlags) Get() interface{} {
	return ""
}

// Set appends value the array of flags.
func (f *ArrayStringFlags) Set(value string) error {
	*f = append(*f, value)
	return nil
}

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

// LayerParts contains paths to the components needed to fully describe a
// docker image layer.
type LayerParts struct {
	// CompressedTarball is the path to the compressed layer tarball.
	CompressedTarball string
	// UncompressedTarball is the path to the uncompressed layer tarball.
	UncompressedTarball string
	// DigestFile is the path to a file containing the sha256 digest of the
	// compressed layer.
	DigestFile string
	// DiffIDFile is the path to a file containing the sha256 digest of the
	// uncompressed layer.
	DiffIDFile string
}

// V1Layer returns a v1.Layer for the given LayerParts.
func (l *LayerParts) V1Layer() (v1.Layer, error) {
	result := &fullLayer{
		compressedTarball:   l.CompressedTarball,
		uncompressedTarball: l.UncompressedTarball,
	}
	if err := result.loadHashes(l.DigestFile, l.DiffIDFile); err != nil {
		return nil, errors.Wrapf(err, "unable to load the hashes for compressed layer at %s", l.CompressedTarball)
	}
	return result, nil
}

// LayerPartsFromString constructs a LayerParts object from a string in the
// format val1,val2,val3,val4 where:
// val1 is the compressed layer tarball.
// val2 is the uncompressed layer tarball.
// val3 is the digest file.
// val4 is the diffID file.
func LayerPartsFromString(val string) (LayerParts, error) {
	split := strings.Split(val, ",")
	if len(split) != 4 {
		return LayerParts{}, errors.Errorf("given layer parts string %q split into unexpected elements by ',', got %d, want 4", val, len(split))
	}
	return LayerParts{
		CompressedTarball:   split[0],
		UncompressedTarball: split[1],
		DigestFile:          split[2],
		DiffIDFile:          split[3],
	}, nil
}

// ImageParts contains paths to a Docker image config and the invidual layer
// parts.
type ImageParts struct {
	// Config is the path to the image config.
	Config string
	// Layers are the parts of layers in the image defined by this object.
	Layers []LayerParts
}

// ImagePartsFromArgs is a convenience function to convert string arguments
// defining the parts of an image:
// imgConfig is the path to the image config.
// layers are strings where each item has the format val1,val2,val3,val4 where:
//   val1 is the compressed layer tarball.
//   val2 is the uncompressed layer tarball.
//   val3 is the digest file.
//   val4 is the diffID file.
// to an ImageParts object.
func ImagePartsFromArgs(imgConfig string, layers []string) (ImageParts, error) {
	if len(layers) > 0 && imgConfig == "" {
		return ImageParts{}, errors.Errorf("image config was not provided even though %d layer parts were specified", len(layers))
	}
	result := ImageParts{Config: imgConfig}
	for _, l := range layers {
		lp, err := LayerPartsFromString(l)
		if err != nil {
			return ImageParts{}, errors.Wrapf(err, "unable to extract layer parts from %q", l)
		}
		result.Layers = append(result.Layers, lp)
	}
	return result, nil
}

// ReadImage loads a v1.Image either directly from an image tarball or from
// the given ImageParts.
// Either *only* the image tarball must be specified or the ImageParts.
// The returned image won't need to digest the actual layer contents to
// calculate the layer digests & diffIDs when using the image parts.
func ReadImage(imgTarball string, imgParts ImageParts) (v1.Image, error) {
	if imgTarball != "" {
		img, err := tarball.ImageFromPath(imgTarball, nil)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to read image from tarball %s", imgTarball)
		}
		return img, nil
	}
	layerOpts := []compat.LayerOpts{}
	for _, l := range imgParts.Layers {
		layer, err := l.V1Layer()
		if err != nil {
			return nil, errors.Wrap(err, "unable to build a v1.Layer from the specified parts")
		}
		layerOpts = append(layerOpts, compat.LayerOpts{
			Layer: layer,
		})
	}
	return compat.Read(imgParts.Config, layerOpts)
}
