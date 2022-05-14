package compat

import (
	"testing"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
	"github.com/google/go-containerregistry/pkg/v1/random"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

func generateRandomImage(t testing.TB) v1.Image {
	cl, err := random.Layer(256, types.DockerLayer)
	if err != nil {
		t.Fatalf("Unable to generate a random compressed layer: %v", err)
	}

	ul, err := random.Layer(256, types.DockerUncompressedLayer)
	if err != nil {
		t.Fatalf("Unable to generate a random uncompressed layer: %v", err)
	}

	img, err := mutate.AppendLayers(empty.Image, cl, ul)
	if err != nil {
		t.Fatalf("Unable to generate a test image with a compressed & uncompressed layer: %v", err)
	}

	return img
}
