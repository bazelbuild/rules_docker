package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"os"

	"github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

// image is an optimal representation of an on-disk collection of compressed
// image layers and a config file.
type image struct {
	rawConfigFile []byte
	rawManifest   []byte
	configDigest  v1.Hash
	layers        map[v1.Hash]partial.CompressedLayer
}

var _ partial.CompressedImageCore = (*image)(nil)

// RawConfigFile implements partial.CompressedImageCore
func (i *image) RawConfigFile() ([]byte, error) {
	return i.rawConfigFile, nil
}

// MediaType implements partial.CompressedImageCore
func (i *image) MediaType() (types.MediaType, error) {
	return types.DockerManifestSchema2, nil
}

// RawManifest implements partial.CompressedImageCore
func (i *image) RawManifest() ([]byte, error) {
	return i.rawManifest, nil
}

// LayerByDigest implements partial.CompressedImageCore
func (i *image) LayerByDigest(h v1.Hash) (partial.CompressedLayer, error) {
	if h == i.configDigest {
		return partial.ConfigLayer(i)
	}
	l, ok := i.layers[h]
	if !ok {
		return nil, fmt.Errorf("unexpected hash when getting layers: %v", h)
	}
	return l, nil
}

type layer struct {
	hash     v1.Hash
	filePath string
	size     int64
}

var _ partial.CompressedLayer = (*layer)(nil)

// Digest implements partial.CompressedLayer
func (l *layer) Digest() (v1.Hash, error) {
	return l.hash, nil
}

// Compressed implements partial.CompressedLayer
func (l *layer) Compressed() (io.ReadCloser, error) {
	return os.Open(l.filePath)
}

// Size implements partial.CompressedLayer
func (l *layer) Size() (int64, error) {
	return l.size, nil
}

func fileSize(filePath string) (int64, error) {
	fi, err := os.Stat(filePath)
	if err != nil {
		return -1, err
	}
	return fi.Size(), nil
}

func fromDisk(configFilePath string, compressedLayerPaths, layerDigestPaths []string) (v1.Image, error) {
	if len(compressedLayerPaths) != len(layerDigestPaths) {
		return nil, fmt.Errorf("layer digest paths and file paths must have the same length")
	}
	var err error

	img := image{layers: make(map[v1.Hash]partial.CompressedLayer)}
	img.rawConfigFile, err = ioutil.ReadFile(configFilePath)
	if err != nil {
		return nil, fmt.Errorf("reading file %q: %v", configFilePath, err)
	}

	img.configDigest, _, err = v1.SHA256(bytes.NewReader(img.rawConfigFile))
	if err != nil {
		return nil, err
	}
	m := v1.Manifest{
		SchemaVersion: 2,
		MediaType:     types.DockerManifestSchema2,
		Config: v1.Descriptor{
			MediaType: types.DockerConfigJSON,
			Size:      int64(len(img.rawConfigFile)),
			Digest:    img.configDigest,
		},
		Layers: make([]v1.Descriptor, 0, len(layerDigestPaths)),
	}

	// Layers
	for i, lPath := range compressedLayerPaths {
		hash, err := readDigest(layerDigestPaths[i])
		if err != nil {
			return nil, err
		}
		size, err := fileSize(lPath)
		if err != nil {
			return nil, err
		}

		m.Layers = append(m.Layers, v1.Descriptor{
			MediaType: types.DockerLayer,
			Size:      size,
			Digest:    hash,
		})

		img.layers[hash] = &layer{
			hash:     hash,
			filePath: lPath,
			size:     size,
		}
	}

	// Manifest
	img.rawManifest, err = json.Marshal(&m)
	if err != nil {
		return nil, err
	}

	return partial.CompressedToImage(&img)
}

func readDigest(layerDigestPath string) (v1.Hash, error) {
	b, err := ioutil.ReadFile(layerDigestPath)
	if err != nil {
		return v1.Hash{}, fmt.Errorf("reading file %q: %v", layerDigestPath, err)
	}
	return v1.NewHash("sha256:" + string(b))
}
