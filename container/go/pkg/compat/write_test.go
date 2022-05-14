package compat

import (
	"os"
	"testing"
)

func TestWriteImage(t *testing.T) {
	img := generateRandomImage(t)

	if err := WriteImage(img, os.Getenv("TEST_TMPDIR")); err != nil {
		t.Errorf("Unable to write test image: %v", err)
	}
}
