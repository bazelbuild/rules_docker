package utils

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"

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

// ReadImageWithCompressedLayers loads v1.Image with the given config and
// given compressed layer files in Docker format. This method will manully
// hash the layer tarballs to generate the layer digests if requested from the
// returned image.
func ReadImageWithCompressedLayers(imgConfig string, layersPath []string) (v1.Image, error) {
	layers := []compat.LayerOpts{}
	for _, l := range layersPath {
		layers = append(layers, compat.LayerOpts{
			Type: types.DockerLayer,
			Path: l,
		})
	}
	return compat.Read(imgConfig, layers)
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

// ReadImageWithFullLayers loads a v1.Image with the given:
// 1. Image config.
// 2. Compressed docker layer tarballs in order.
// 3. Uncompressed docker layer tarballs in order.
// 4. Files with the digests of the compressed layer tarballs in order.
// 5. Files with the diffID's of the uncompressed layer tarballs in order.
// The returned image won't need to digest the actual layer contents to
// calculate the layer digests & diffIDs.
func ReadImageWithFullLayers(imgConfig string, compressedLayers, uncompressedLayers, digests, diffIDs []string) (v1.Image, error) {
	if len(compressedLayers) != len(uncompressedLayers) ||
		len(uncompressedLayers) != len(digests) ||
		len(digests) != len(diffIDs) {
		return nil, errors.Errorf("got unequal number of layer parts for compressed layers, uncompressed layers, digest files, diff ID files, got %d, %d, %d, %d, want all of them to be equal", len(compressedLayers), len(uncompressedLayers), len(digests), len(diffIDs))
	}
	layers := []compat.LayerOpts{}
	for i, cl := range compressedLayers {
		fl := &fullLayer{
			compressedTarball:   cl,
			uncompressedTarball: uncompressedLayers[i],
		}
		if err := fl.loadHashes(digests[i], diffIDs[i]); err != nil {
			return nil, errors.Wrapf(err, "unable to load the digest & diffID for layer with compressed tarball %s", cl)
		}
		layers = append(layers, compat.LayerOpts{
			Layer: fl,
		})
	}
	return compat.Read(imgConfig, layers)
}
