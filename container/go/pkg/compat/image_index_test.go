package compat

import (
	"testing"

	"github.com/google/go-containerregistry/pkg/v1/types"

	v1 "github.com/google/go-containerregistry/pkg/v1"
)

func TestImageIndex(t *testing.T) {
	img1 := generateRandomImage(t)
	p1 := v1.Platform{
		Architecture: "amd64",
		OS:           "linux",
	}

	img2 := generateRandomImage(t)
	p2 := v1.Platform{
		Architecture: "arm64",
		OS:           "linux",
		Variant:      "v8",
	}

	ii, err := NewImageIndex([]v1.Platform{p1, p2}, []v1.Image{img1, img2})
	if err != nil {
		t.Fatalf("Unable to create image index: %v", err)
	}

	t.Run("MediaType", func(t *testing.T) {
		md, err := ii.MediaType()
		if err != nil {
			t.Fatalf("Unable to get image index media type: %v", err)
		}

		if md != types.DockerManifestList {
			t.Fatalf(
				"Image index media type incorrect, returned %v, expected %v",
				md, types.DockerManifestList,
			)
		}
	})

	t.Run("Digest", func(t *testing.T) {
		h, err := ii.Digest()
		if err != nil {
			t.Fatalf("Unable to get image index digest: %v", err)
		}

		const (
			// sha256 of empty string.
			emptyDigest = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
			zeroDigest  = ":"
		)

		if h.String() == zeroDigest || h.String() == emptyDigest {
			t.Fatalf(
				"Image index digest incorrect, must be different than %q and %q, returned %q",
				zeroDigest, emptyDigest, h.String(),
			)
		}
	})

	t.Run("Size", func(t *testing.T) {
		size, err := ii.Size()
		if err != nil {
			t.Fatalf("Unable to get image index size: %v", err)
		}

		if size <= 0 {
			t.Fatalf("Image index size should not be negative or null, returned %d", size)
		}
	})

	t.Run("IndexManifest", func(t *testing.T) {
		im, err := ii.IndexManifest()
		if err != nil {
			t.Fatalf("Unable to get image index manifest: %v", err)
		}

		if len(im.Manifests) != 2 {
			t.Fatalf(
				"Incorrect number of manifest, expected 2, returned %d",
				len(im.Manifests),
			)
		}

		if im.MediaType != types.DockerManifestList {
			t.Fatalf(
				"Image index media type incorrect, returned %v, expected %v",
				im.MediaType, types.DockerManifestList,
			)
		}

		assertImageDigest(t, img1, im.Manifests[0].Digest)
		assertPlatform(t, p1, im.Manifests[0].Platform)

		assertImageDigest(t, img2, im.Manifests[1].Digest)
		assertPlatform(t, p2, im.Manifests[1].Platform)
	})

	t.Run("RawManifest", func(t *testing.T) {
		rawManifest, err := ii.RawManifest()
		if err != nil {
			t.Fatalf("Unable to get raw manifest: %v", err)
		}

		if len(rawManifest) == 0 {
			t.Fatal("Raw manigest is empty")
		}
	})

	t.Run("Image", func(t *testing.T) {
		for _, expectedImage := range []v1.Image{img1, img2} {
			expectedDigest, err := expectedImage.Digest()
			if err != nil {
				t.Fatalf("Unable to get image digest: %v", err)
			}

			if _, err := ii.Image(expectedDigest); err != nil {
				t.Fatalf("Unable to get image with digest %q: %v", expectedDigest, err)
			}
		}
	})
}

func assertImageDigest(t testing.TB, img v1.Image, digest v1.Hash) {
	expectedDigest, err := img.Digest()
	if err != nil {
		t.Fatalf("Unable to get image digest: %v", err)
	}

	if expectedDigest.String() != digest.String() {
		t.Fatalf(
			"Incorrect image digest, expected %q, returned %q",
			expectedDigest, digest,
		)
	}
}

func assertPlatform(t testing.TB, expectedPlatform v1.Platform, p *v1.Platform) {
	if !p.Equals(expectedPlatform) {
		t.Fatalf(
			"Incorrect platform, expected %+v, returned %+v",
			expectedPlatform, p,
		)
	}
}
