// Copyright 2016 The Bazel Authors. All rights reserved.
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
// Binary join_layers creates a Docker image tarball from a base image and a
// list of image layers.
package main

import (
	"flag"
	"io/ioutil"
	"log"
	"os"
	"strings"

	"github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/pkg/errors"
)

var (
	outputTarball  = flag.String("output", "", "Path to the output image tarball.")
	tags           utils.ArrayStringFlags
	basemanifests  utils.ArrayStringFlags
	layers         utils.ArrayStringFlags
	sourceImages   utils.ArrayStringFlags
	stampInfoFiles utils.ArrayStringFlags
)

// layerData is a collection of files that has the contents and metadata about
// an image layer.
type layerData struct {
	// layer represents a v1.Layer directly.
	layer v1.Layer
	// Type is the type of this layer.
	mediaType types.MediaType
	// diffID is the digest of the uncompressed blob of this layer.
	diffID string
	// digest is the digest of the compressed blob of this layer.
	digest string
	// compressedBlob is the path to the compressed layer tarball.
	compressedBlob string
	// diffIDFile is the file from which the diffID for this layer was read.
	diffIDFile string
	// digestFile is the file from which the digest for this layer was read.
	digestFile string
	// size is the size of this layer. Only needed for foreign layers.
	size int64
	// urls are the urls to download this layer from. Only needed for foreign
	// layers.
	urls []string
}

// layerOpts returns the compat.LayerOpts object corresponding to the given
// layerData.
func (l *layerData) layerOpts() compat.LayerOpts {
	return compat.LayerOpts{
		Layer:  l.layer,
		Digest: l.digest,
		DiffID: l.diffID,
		Path:   l.compressedBlob,
		Size:   l.size,
		Type:   l.mediaType,
		URLS:   l.urls,
	}
}

// initLayerData creates a new layerData object with the given parameters and
// loads the values of the hashes into the layerData object from the given
// diffID and digest files.
func initLayerData(diffIDfile, digestFile, compressedBlob string) (layerData, error) {
	ld := layerData{
		mediaType:      types.DockerLayer,
		compressedBlob: compressedBlob,
		diffIDFile:     diffIDfile,
		digestFile:     digestFile,
	}
	diffID, err := ioutil.ReadFile(ld.diffIDFile)
	if err != nil {
		return layerData{}, errors.Wrapf(err, "unable to read diffID for layer from %s", ld.diffIDFile)
	}
	ld.diffID = string(diffID)
	digest, err := ioutil.ReadFile(ld.digestFile)
	if err != nil {
		return layerData{}, errors.Wrapf(err, "unable to read digest for layer from %s", ld.digestFile)
	}
	ld.digest = string(digest)
	return ld, nil
}

// parseTagToFilename converts a list of key=value where 'key' is the name of
// the tagged image and 'value' is the path to a file into a map from key to
// value.
func parseTagToFilename(tags []string, stamper *compat.Stamper) (map[name.Tag]string, error) {
	result := make(map[name.Tag]string)
	for _, t := range tags {
		split := strings.Split(t, "=")
		if len(split) != 2 {
			return nil, errors.Errorf("%q was not specified in the expected key=value format because it split into unexpected number of elements by '=', got %d, want 2", t, len(split))
		}
		img, configFile := split[0], split[1]
		img = stamper.Stamp(img)
		parsedTag, err := name.NewTag(img, name.WeakValidation)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to parse stamped image name %q as a fully qualified tagged image name", img)
		}
		result[parsedTag] = configFile
	}
	return result, nil
}

// loadImgLayersData adds layerData objects for the given image to the given
// list of layerData.
func loadImgLayersData(img v1.Image, layersData []layerData) error {
	layers, err := img.Layers()
	if err != nil {
		return errors.Wrap(err, "unable to get image layers")
	}
	for _, l := range layers {
		// Set the digest & diffID fields in the layerData object because it
		// will be used by uniquifyLayerData to de-duplicate layers and
		// imageLayers to identify what layers belong to the image being built.
		d, err := l.Digest()
		if err != nil {
			return errors.Wrap(err, "unable to get layer digest")
		}
		diffID, err := l.DiffID()
		if err != nil {
			return errors.Wrap(err, "unable to get layer diffID")
		}
		layersData = append(layersData, layerData{
			layer:  l,
			digest: d.Hex,
			diffID: diffID.Hex,
		})
	}
	return nil
}

// uniquifyLayerData removes duplicate layers from the given list of layerData
// objects. Duplicate layers that occur later in the list replace earlier
// occurences. The uniquified list is returned. The given list is not modified.
func uniquifyLayerData(layersData []layerData) []layerData {
	result := []layerData{}
	lookup := make(map[string]bool)
	// Scan in reverse order and reject duplicates found earlier in the list.
	for i := len(layersData) - 1; i >= 0; i-- {
		l := layersData[i]
		_, ok := lookup[l.digest]
		if ok {
			continue
		}
		lookup[l.digest] = true
		result = append(result, l)
	}
	return result
}

// loadLayersData creates layer data objects from the given list of base image
// tarballs and a list of strings where each string has the format
// val1,val2,val3 where:
// val1 is the file containing the layer diffID.
// val2 is the file containing the layer digest.
// val3 is the path to the compressed layer tarball.
func loadLayersData(sourceImages, layers []string) ([]layerData, error) {
	result := []layerData{}
	for _, imgPath := range sourceImages {
		img, err := tarball.ImageFromPath(imgPath, nil)
		if err != nil {
			return nil, errors.Wrapf(err, "unable to load base image tarball from %s", imgPath)
		}
		if err := loadImgLayersData(img, result); err != nil {
			return nil, errors.Wrapf(err, "unable to load layers from base image tarball %s", imgPath)
		}
	}
	for _, l := range layers {
		split := strings.Split(l, ",")
		if len(split) != 3 {
			return nil, errors.Errorf("%q did not split by ',' into the expected number of elements, got %d, want 4", l, len(split))
		}
		ld, err := initLayerData(split[0], split[1], split[2])
		if err != nil {
			return nil, errors.Wrap(err, "unable to load layer data")
		}
		result = append(result, ld)
	}
	return uniquifyLayerData(result), nil
}

// buildDiffIDToLayer builds a map from layer diffID to layer data from
// the given list of layer data.
func buildDiffIDToLayer(layersData []layerData) map[string]layerData {
	result := make(map[string]layerData)
	for _, l := range layersData {
		result[l.diffID] = l
	}
	return result
}

// diffIDToLayerFromManifest generates a diffID to layerData lookup from the
// layers in the given base manifest if the manifest defines any layers. The
// manifest is only expected to define layers when the image being built is
// a windows image with a base image with foreign layers.
func diffIDToLayerFromManifest(config *v1.ConfigFile, manifest *v1.Manifest) (map[string]layerData, error) {
	if len(manifest.Layers) == 0 {
		// A manifest was not specified or a blank manifest was specified. This
		// means this image doesn't have any foreign layers so nothing to do
		// here.
		return nil, nil
	}
	// The manifest is from the base image which may have fewer layers than the
	// config. However, the config shouldn't have removed any of the layers from
	// the original base manifest.
	if len(config.RootFS.DiffIDs) < len(manifest.Layers) {
		return nil, errors.Errorf("unexpected number of layers in config %d vs manifest %d, want config to have equal or great number of layers", len(config.RootFS.DiffIDs), len(manifest.Layers))
	}
	result := make(map[string]layerData)
	// Manifest layers should only be specified for foreign layers which are
	// a special kind of layer in Windows base images. For every other layer,
	// the layer tarball should be specified with the --layer flag instead.
	for i, l := range manifest.Layers {
		if l.MediaType != types.DockerForeignLayer {
			return nil, errors.Errorf("unexpected layer of type in manifest, got %s, want foreign layer type %s", l.MediaType, types.DockerForeignLayer)
		}
		diffID := config.RootFS.DiffIDs[i]
		result[diffID.Hex] = layerData{
			mediaType: types.DockerForeignLayer,
			diffID:    diffID.Hex,
			digest:    l.Digest.Hex,
			size:      l.Size,
			urls:      l.URLs,
		}
	}
	return result, nil
}

// imageLayers returns the layer files from the given layer data lookup for
// an image with the given config JSON file.
func imageLayers(cfg *v1.ConfigFile, tarballLayers, manifestLayers map[string]layerData) ([]compat.LayerOpts, error) {
	result := []compat.LayerOpts{}
	for _, d := range cfg.RootFS.DiffIDs {
		layer, ok := tarballLayers[d.Hex]
		if ok {
			result = append(result, layer.layerOpts())
			continue
		}
		layer, ok = manifestLayers[d.Hex]
		if ok {
			result = append(result, layer.layerOpts())
			continue
		}
		return nil, errors.Errorf("did not find layer with diffID %s specified in image config", d)
	}
	return result, nil
}

// loadImageMetadata loads the image config and optionally the manifest for
// the image with the given tag using the given tag to config file & manifest
// file lookups.
func loadImageMetadata(tag name.Tag, tagToConfigs, tagToBaseManifests map[name.Tag]string) (*v1.ConfigFile, *v1.Manifest, error) {
	configFile, ok := tagToConfigs[tag]
	if !ok {
		return nil, nil, errors.Errorf("unable to find the config file for image %v", tag)
	}
	cf, err := os.Open(configFile)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "unable to open config for image %v from %s", tag, configFile)
	}
	cfg, err := v1.ParseConfigFile(cf)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "unable to parse image config for %v from %s", tag, configFile)
	}
	manifestFile, ok := tagToBaseManifests[tag]
	if !ok {
		// Manifest is optional and is only needed to build images whose base
		// image had foreign layers. Just return the config.
		return cfg, &v1.Manifest{}, nil
	}
	mf, err := os.Open(manifestFile)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "unable to open manifest for image %v from %s", tag, manifestFile)
	}
	m, err := v1.ParseManifest(mf)
	if err != nil {
		return nil, nil, errors.Wrapf(err, "unable to parse manifest for image %v from %s", tag, manifestFile)
	}
	return cfg, m, nil
}

// writeOutput creates a multi-image tarball at the given output path using
// the images defined by the given tag to config & manifest maps with the
// given layers based on the given source images.
func writeOutput(outputTarball string, tagToConfigs, tagToBaseManifests map[name.Tag]string, layersData []layerData) error {
	tagToImg := make(map[name.Tag]v1.Image)
	layerLookup := buildDiffIDToLayer(layersData)
	for tag, configFile := range tagToConfigs {
		config, manifest, err := loadImageMetadata(tag, tagToConfigs, tagToBaseManifests)
		if err != nil {
			return errors.Wrapf(err, "unable to load config & manifest for image %v", tag)
		}
		manifestLayers, err := diffIDToLayerFromManifest(config, manifest)
		if err != nil {
			return errors.Wrapf(err, "unable to get layers defined in manifest and config for image %v", tag)
		}
		layerOpts, err := imageLayers(config, layerLookup, manifestLayers)
		if err != nil {
			return errors.Wrapf(err, "unable to select the layer tarball files for image %v using its manifest", tag)
		}
		img, err := compat.Read(configFile, layerOpts)
		if err != nil {
			return errors.Wrapf(err, "unable to load image %v corresponding to config %s", tag, configFile)
		}
		tagToImg[tag] = img
	}
	return tarball.MultiWriteToFile(outputTarball, tagToImg)
}

func main() {
	flag.Var(&tags, "tag", "One or more fully qualified tag names along with the path to the config of the image they tag in tag=path format. e.g., --tag ubuntu=path/to/config1.json --tag gcr.io/blah/debian=path/to/config2.json.")
	flag.Var(&basemanifests, "basemanifest", "One or more fully qualified tag names along with the manifest of the base image in tag=manifest format. e.g., --manifest ubuntu=path/to/manifest1.json --manifest gcr.io/blah/debian=path/to/manifest2.json.")
	flag.Var(&layers, "layer", "One or more layers with the following comma separated values (Diff ID file, Digest file, Compressed layer tarball). e.g., --layer diffa,hash,layer1.tar,layer1.tar.gz.")
	flag.Var(&sourceImages, "source_image", "One or more image tarballs for images from which the output image of this binary may derive. e.g., --source_image imag1.tar --source_image image2.tar.")
	flag.Var(&stampInfoFiles, "stamp_info_file", "Path to one or more Bazel stamp info file with key value pairs for substitution.")
	flag.Parse()

	stamper, err := compat.NewStamper(stampInfoFiles)
	if err != nil {
		log.Fatalf("Unable to initialize stamper: %v", err)
	}
	tagToConfig, err := parseTagToFilename(tags, stamper)
	if err != nil {
		log.Fatalf("Unable to process values passed using the flag --tag: %v", err)
	}
	tagToBaseManifest, err := parseTagToFilename(basemanifests, stamper)
	if err != nil {
		log.Fatalf("Unable to process values passed using the flag --manifest: %v", err)
	}
	layersData, err := loadLayersData(sourceImages, layers)
	if err != nil {
		log.Fatalf("Unable to process values passed using the flag --layer: %v", err)
	}
	if err := writeOutput(*outputTarball, tagToConfig, tagToBaseManifest, layersData); err != nil {
		log.Fatalf("Failed to generate output at %s: %v", *outputTarball, err)
	}
}
