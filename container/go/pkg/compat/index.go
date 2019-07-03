package compat

import (
	"fmt"
	"io/ioutil"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

// ImageIndexFromPath is a convenience function which constructs a Path and returns its v1.ImageIndex.
func ImageIndexFromPath(path string) (v1.ImageIndex, error) {
	lp, err := FromPath(path)
	if err != nil {
		return nil, err
	}
	return lp.ImageIndex()
}

type intermediateLayout struct {
	path        Path
	rawManifest []byte
}

// MediaType of this image's manifest.
func (i *intermediateLayout) MediaType() (types.MediaType, error) {
	return types.OCIImageIndex, nil
}

// Digest returns the sha256 of this index's manifest.
func (i *intermediateLayout) Digest() (v1.Hash, error) {
	// Read and parse the manifest digest hash, expecting a file named digest.
	digest, err := ioutil.ReadFile(i.path.path("digest"))
	if err != nil {
		fmt.Errorf("Failed to locate SHA256 digest file for image manifest: %v", err)
	}

	return v1.NewHash(string(digest))
}

// IndexManifest returns this image index's manifest object.
func (i *intermediateLayout) IndexManifest() (*v1.IndexManifest, error) {
	manifest, err := partial.Manifest(i)
	if err != nil {
		return nil, fmt.Errorf("Failed to parse raw manifest, please check if a correctly formatted manifest.json exists %v", err)
	}
	manifestDigest, err := i.Digest()
	if err != nil {
		return nil, fmt.Errorf("Failed to parse image manifest hash, please check if a digest file exists in the directory and it is formatted as {Algorithm}:{Hash} %v", err)
	}

	index := v1.IndexManifest{
		SchemaVersion: manifest.SchemaVersion,
		Manifests: []v1.Descriptor{
			v1.Descriptor{
				MediaType: manifest.MediaType,
				Size:      int64(len(i.rawManifest)),
				Digest:    manifestDigest,
			},
		},
	}

	return &index, nil
}

// RawManifest returns the serialized bytes of IndexManifest().
func (i *intermediateLayout) RawManifest() ([]byte, error) {
	return i.rawManifest, nil
}

// Image returns a v1.Image that this ImageIndex references.
func (i *intermediateLayout) Image(h v1.Hash) (v1.Image, error) {
	// Look up the digest in our manifest first to return a better error.
	desc, err := i.findDescriptor(h)
	if err != nil {
		return nil, err
	}

	if !isExpectedMediaType(desc.MediaType, types.OCIManifestSchema1, types.DockerManifestSchema2) {
		return nil, fmt.Errorf("unexpected media type for %v: %s", h, desc.MediaType)
	}

	img := &layoutImage{
		path: i.path,
		desc: *desc,
	}
	return partial.CompressedToImage(img)
}

func (i *intermediateLayout) findDescriptor(h v1.Hash) (*v1.Descriptor, error) {
	im, err := i.IndexManifest()
	if err != nil {
		return nil, err
	}

	for _, desc := range im.Manifests {
		if desc.Digest == h {
			return &desc, nil
		}
	}

	return nil, fmt.Errorf("could not find descriptor in index: %s", h)
}

// ImageIndex returns a v1.ImageIndex that this ImageIndex references.
func (i *intermediateLayout) ImageIndex(h v1.Hash) (v1.ImageIndex, error) {
	desc, err := i.findDescriptor(h)
	if err != nil {
		return nil, err
	}

	if !isExpectedMediaType(desc.MediaType, types.OCIImageIndex, types.DockerManifestList) {
		return nil, fmt.Errorf("unexpected media type for %v: %s", h, desc.MediaType)
	}

	return &intermediateLayout{
		path:        i.path,
		rawManifest: i.rawManifest,
	}, nil
}

func isExpectedMediaType(mt types.MediaType, expected ...types.MediaType) bool {
	for _, allowed := range expected {
		if mt == allowed {
			return true
		}
	}
	return false
}
