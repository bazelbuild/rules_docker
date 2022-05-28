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
// Reads an legacy image layout on disk.
package compat

import (
	"bytes"
	"io"
	"io/ioutil"
	"os"
	"strings"

	"github.com/google/go-containerregistry/pkg/v1/tarball"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

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

// ImageParts contains paths to a Docker image config and the individual layer
// parts.
type ImageParts struct {
	// Config is the path to the image config.
	Config string
	// BaseManifest is the path to the manifest of the base image.
	BaseManifest string
	// ImageTarball is the path to the image tarball whose layers can
	// be extended by the layers in LayerParts.
	ImageTarball string
	// Images are the v1.Images whose layers can be extended by the layers in
	// LayerParts.
	Images []v1.Image
	// Layers are the parts of layers in the image defined by this object.
	Layers []LayerParts
}

// ImagePartsFromArgs is a convenience function to convert string arguments
// defining the parts of an image:
// config is the path to the image config.
// baseManifest is the path to the manifest of the first image in the chain
// of images.
// imgTarball is the path to the image tarball. This will be used as the base
// image if one or more layers are specified.
// layers are strings where each item has the format val1,val2,val3,val4 where:
//   val1 is the compressed layer tarball.
//   val2 is the uncompressed layer tarball.
//   val3 is the digest file.
//   val4 is the diffID file.
// to an ImageParts object.
func ImagePartsFromArgs(config, baseManifest, imgTarball string, layers []string) (ImageParts, error) {
	result := ImageParts{Config: config, BaseManifest: baseManifest, ImageTarball: imgTarball}
	for _, l := range layers {
		lp, err := LayerPartsFromString(l)
		if err != nil {
			return ImageParts{}, errors.Wrapf(err, "unable to extract layer parts from %q", l)
		}
		result.Layers = append(result.Layers, lp)
	}
	return result, nil
}

// Reader maintains the state necessary to build a legacyImage object from an
// ImageParts object.
type Reader struct {
	// parts is the ImageParts being loaded.
	Parts ImageParts
	// baseManifest is the manifest of the very first base image in the chain
	// of images being loaded.
	baseManifest *v1.Manifest
	// config is the config of the image being loaded.
	config *v1.ConfigFile
	// layerLookup is a map from the diffID of a layer to the layer
	// itself.
	layerLookup map[v1.Hash]v1.Layer
	// loadedImageCache is a cache of all images that have been loaded into memory,
	// to prevent costly reloads.
	loadedImageCache map[v1.Hash]bool
}

// loadMetadata loads the image metadata for the image parts in the given
// reader.
func (r *Reader) loadMetadata() error {
	cf, err := os.Open(r.Parts.Config)
	if err != nil {
		return errors.Wrapf(err, "unable to open image config file %s", r.Parts.Config)
	}
	c, err := v1.ParseConfigFile(cf)
	if err != nil {
		return errors.Wrapf(err, "unable to parse image config from %s", r.Parts.Config)
	}
	r.config = c
	if r.Parts.BaseManifest == "" {
		// Base manifest is optional. It's only needed for images whose base
		// manifests have foreign layers.
		return nil
	}
	mf, err := os.Open(r.Parts.BaseManifest)
	if err != nil {
		return errors.Wrapf(err, "unable to open base image manifest file %s", r.Parts.BaseManifest)
	}
	m, err := v1.ParseManifest(mf)
	if err != nil {
		return errors.Wrapf(err, "unable to parse base image manifest from %s", r.Parts.BaseManifest)
	}
	r.baseManifest = m
	return nil
}

// foreignLayer represents a foreign layer usually present in Windows images.
type foreignLayer struct {
	// digest is the digest of this foreign layer.
	digest v1.Hash
	// diffID is the diffID of this foreign layer.
	diffID v1.Hash
	// size is the size of the foreign layer.
	size int64
	// urls are the URLs where the actual contents of the foreign layer can
	// be downloaded from.
	urls []string
}

var _ v1.Layer = (*foreignLayer)(nil)

// DiffID returns the diffID of this foreign layer.
func (l *foreignLayer) DiffID() (v1.Hash, error) {
	return l.diffID, nil
}

// Digest returns the digest of this foreign layer.
func (l *foreignLayer) Digest() (v1.Hash, error) {
	return l.digest, nil
}

// Uncompressed returns a blank reader for this foreign layer.
func (l *foreignLayer) Uncompressed() (io.ReadCloser, error) {
	r := bytes.NewReader([]byte{})
	return ioutil.NopCloser(r), nil
}

// Compressed returns a blank reader for this foreign layer.
func (l *foreignLayer) Compressed() (io.ReadCloser, error) {
	return l.Uncompressed()
}

// Size returns the number of bytes in the compressed version of this layer.
func (l *foreignLayer) Size() (int64, error) {
	return 0, nil
}

// MediaType returns the media type of this foreign layer.
func (l *foreignLayer) MediaType() (types.MediaType, error) {
	return types.DockerForeignLayer, nil
}

// loadForeignLayers loads the foreign layers from the base manifest in the
// given reader into the layer lookup.
func (r *Reader) loadForeignLayers() error {
	if r.baseManifest == nil {
		// No base manifest so no foreign layers to load.
		return nil
	}
	// The manifest is from the base image which may have fewer layers than the
	// config. However, the config shouldn't have removed any of the layers from
	// the original base manifest.
	if len(r.config.RootFS.DiffIDs) < len(r.baseManifest.Layers) {
		return errors.Errorf("unexpected number of layers in config %d vs manifest %d, want config to have equal or greater number of layers", len(r.config.RootFS.DiffIDs), len(r.baseManifest.Layers))
	}
	for i, l := range r.baseManifest.Layers {
		if l.MediaType != types.DockerForeignLayer {
			continue
		}
		diffID := r.config.RootFS.DiffIDs[i]
		r.layerLookup[diffID] = &foreignLayer{
			digest: l.Digest,
			diffID: diffID,
			size:   l.Size,
			urls:   l.URLs,
		}
	}
	return nil
}

// loadImages loads the layers from the given images into the layers lookup
// in the given reader.
func (r *Reader) loadImages(images []v1.Image) error {
	for _, img := range images {
		digest, _ := img.Digest()
		if r.loadedImageCache[digest] {
			continue
		}
		layers, err := img.Layers()
		if err != nil {
			return errors.Wrap(err, "unable to get the layers in image")
		}
		for _, l := range layers {
			diffID, err := l.DiffID()
			if err != nil {
				return errors.Wrap(err, "unable to get diffID from layer")
			}
			r.layerLookup[diffID] = l
		}
		r.loadedImageCache[digest] = true
	}
	return nil
}

// loadImgTarball loads the layers from the image tarball in the parts section
// of the given reader if one was specified into the layers lookup in the given
// reader.
func (r *Reader) loadImgTarball() error {
	if r.Parts.ImageTarball == "" {
		return nil
	}
	img, err := tarball.ImageFromPath(r.Parts.ImageTarball, nil)
	if err != nil {
		return errors.Wrapf(err, "unable to load image from tarball %s", r.Parts.ImageTarball)
	}
	if err := r.loadImages([]v1.Image{img}); err != nil {
		return errors.Wrapf(err, "unable to load the layers from image loaded from tarball %s", r.Parts.ImageTarball)
	}
	return nil
}

// loadLayers loads layers specified as parts in the ImageParts section in the
// given reader.
func (r *Reader) loadLayers() error {
	for _, l := range r.Parts.Layers {
		layer, err := l.V1Layer()
		if err != nil {
			return errors.Wrap(err, "unable to build a v1.Layer from the specified parts")
		}
		diffID, err := layer.DiffID()
		if err != nil {
			return errors.Wrap(err, "unable to get the diffID from the layer built from parts")
		}
		r.layerLookup[diffID] = layer
	}
	return nil
}

// ReadImage loads a v1.Image from the ImageParts section in the reader.
func (r *Reader) ReadImage() (v1.Image, error) {
	// Special case: if we only have a tarball, we can instantiate the image
	// directly from that. Otherwise, we'll process the image layers
	// individually as specified in the config.
	if r.Parts.ImageTarball != "" && r.Parts.Config == "" {
		return tarball.ImageFromPath(r.Parts.ImageTarball, nil)
	}

	if r.layerLookup == nil {
		r.layerLookup = make(map[v1.Hash]v1.Layer)
	}
	if r.loadedImageCache == nil {
		r.loadedImageCache = make(map[v1.Hash]bool)
	}
	if err := r.loadMetadata(); err != nil {
		return nil, errors.Wrap(err, "unable to load image metadata")
	}
	if err := r.loadImages(r.Parts.Images); err != nil {
		return nil, errors.Wrap(err, "unable to load layers from the images in the given image parts")
	}
	if err := r.loadImgTarball(); err != nil {
		return nil, errors.Wrap(err, "unable to load layers from image tarball")
	}
	if err := r.loadLayers(); err != nil {
		return nil, errors.Wrap(err, "unable to load layers from the given parts")
	}
	if err := r.loadForeignLayers(); err != nil {
		return nil, errors.Wrap(err, "unable to load foreign layers specified in the base manifest")
	}
	layers := []v1.Layer{}
	for _, diffID := range r.config.RootFS.DiffIDs {
		layer, ok := r.layerLookup[diffID]
		if !ok {
			return nil, errors.Errorf("unable to locate layer with diffID %v as indicated in image config %s", diffID, r.Parts.Config)
		}
		layers = append(layers, layer)
	}
	img := &legacyImage{
		configPath: r.Parts.Config,
		layers:     layers,
	}
	if err := img.init(); err != nil {
		return nil, errors.Wrap(err, "unable to initialize image from parts")
	}
	return img, nil
}

// ReadImage loads a v1.Image from the given ImageParts
func ReadImage(parts ImageParts) (v1.Image, error) {
	r := Reader{Parts: parts}
	img, err := r.ReadImage()
	return img, err
}
