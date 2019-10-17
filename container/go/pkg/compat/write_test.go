package compat

import (
	"os"
	"testing"

	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
	"github.com/google/go-containerregistry/pkg/v1/random"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

func TestWriteImage(t *testing.T) {
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
	if err := WriteImage(img, os.Getenv("TEST_TMPDIR")); err != nil {
		t.Errorf("Unable to write test image: %v", err)
	}
}
