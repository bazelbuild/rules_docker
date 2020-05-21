package imagetest

import (
	"testing"

	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

func TestFilesBase(t *testing.T) {
	src := "testdata/files_base.tar"
	p := resolvePath(src)
	img, err := tarball.ImageFromPath(p, nil)
	if err != nil {
		t.Fatalf("Failed to load image from %q: %v", p, err)
	}
	d, err := img.Digest()
	if err != nil {
		t.Errorf("Unable to get digest for image loaded from %q: %v", src, err)
	}
	want := "b7fd957f29c278063427dbbde268bc5a30c422aa80d66a0397716fed0463012f"
	if d.Hex != want {
		t.Errorf("Image %q didn't have expected digest, got %q, want %q.", src, d.Hex, want)
	}

	layers, err := img.Layers()
	if err != nil {
		t.Errorf("Failed to get the layers in image %q: %v", src, err)
	}
	if len(layers) != 1 {
		t.Errorf("Image %q had unexpected number of layers, got %d, want 1.", src, len(layers))
	}
}
