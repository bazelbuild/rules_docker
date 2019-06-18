package oci

import (
	"testing"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/google/go-containerregistry/pkg/v1/validate"
)

var readertests = []struct {
	// A descriptive name for this test case.
	name string
	// The hash code of the manifest metadata file.
	manifestDigest v1.Hash
	// The hash code of the config metadata file.
	configDigest v1.Hash
	// An array of hash codes for each layer in this image.
	layerHashes []v1.Hash
	// The media type of this image.
	mediaType types.MediaType
	// The relative path of this test case.
	testPath string
}{
	// #1 This test index is the output of puller.go
	// from gcr.io/distroless/base@sha256:edc3643ddf96d75032a55e240900b68b335186f1e5fea0a95af3b4cc96020b77.
	{
		"distroless(/test_index1)",
		v1.Hash{
			Algorithm: "sha256",
			Hex:       "edc3643ddf96d75032a55e240900b68b335186f1e5fea0a95af3b4cc96020b77",
		},
		v1.Hash{
			Algorithm: "sha256",
			Hex:       "a0cfcd4cc98a67def7ce9a0c7644d1c415d56d6d44c4a079a447f7eafb253048",
		},
		[]v1.Hash{
			v1.Hash{
				Algorithm: "sha256",
				Hex:       "1558143043601a425aa864511da238799b57fcf7d062d47044f6ddd0e04fe99a",
			},
			v1.Hash{
				Algorithm: "sha256",
				Hex:       "5f5edd681dcbc3a4a9df93e200e59e1708031e65b2299970eabdc91a78cc8234",
			},
		},
		types.DockerManifestSchema2,
		"testdata/test_index1",
	},
}

// TestRead checks the v1.Image outputted by <Read> by validating its manifest, layers and configs.
func TestRead(t *testing.T) {
	for _, rt := range readertests {
		t.Run(rt.name, func(t *testing.T) {
			img, err := Read(rt.testPath)
			if err != nil {
				t.Fatalf("Read(%s): %v", rt.testPath, err)
			}

			// Validates that img does not violate any invariants of the image format by validating the layers, manifests and config.
			if err := validate.Image(img); err != nil {
				t.Errorf("validate.Image(): %v", err)
			}

			mt, err := img.MediaType()
			if err != nil {
				t.Errorf("img.MediaType(): %v", err)
			} else if got, want := mt, rt.mediaType; got != want {
				t.Errorf("img.MediaType(); got: %v want: %v", got, want)
			}

			cfg, err := img.LayerByDigest(rt.configDigest)
			if err != nil {
				t.Fatalf("LayerByDigest(%s): %v", rt.configDigest, err)
			}

			cfgName, err := img.ConfigName()
			if err != nil {
				t.Fatalf("ConfigName(): %v", err)
			}

			cfgDigest, err := cfg.Digest()
			if err != nil {
				t.Fatalf("cfg.Digest(): %v", err)
			}

			if got, want := cfgDigest, cfgName; got != want {
				t.Errorf("ConfigName(); got: %v want: %v", got, want)
			}

			layers, err := img.Layers()
			if err != nil {
				t.Fatalf("img.Layers(): %v", err)
			}

			// Validate the digests and media type for each layer.
			for i, layer := range layers {
				validateLayer(layer, rt.layerHashes[i], i, t)
			}

		})
	}
}

// validateLayer checks if the digests and media type matches for the given layer.
func validateLayer(layer v1.Layer, layerHash v1.Hash, i int, t *testing.T) {
	ld, err := layer.Digest()
	if err != nil {
		t.Fatalf("layers[%d].Digest(): %v", i, err)
	}
	if got, want := ld, layerHash; got != want {
		t.Fatalf("layers[%d].Digest(); got: %q want: %q", i, got, want)
	}

	mt, err := layer.MediaType()
	if err != nil {
		t.Fatalf("layers[%d].MediaType(): %v", i, err)
	}
	if got, want := mt, types.DockerLayer; got != want {
		t.Fatalf("layers[%d].MediaType(); got: %q want: %q", i, got, want)
	}
}
