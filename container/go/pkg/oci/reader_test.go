package oci

import (
	"fmt"
	"testing"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/google/go-containerregistry/pkg/v1/validate"
)

// readerTests has test cases for the Read function that loads a docker image stored on disk serialized in OCI format by "Write".
var readertests = []struct {
	// name is the name of this test case.
	name string
	// manifestDigest is the hash code of the manifest metadata file.
	manifestDigest v1.Hash
	// configDigest is the hash code of the config metadata file.
	configDigest v1.Hash
	// layerHashes is an array of hash codes for each layer in this image.
	layerHashes []v1.Hash
	// mediaType is the media type of this image.
	mediaType types.MediaType
	// testPath is the relative path of this test case.
	testPath string
}{
	// This test index ensures the image downloaded by puller.go from gcr.io/distroless/base@sha256:edc3643ddf96d75032a55e240900b68b335186f1e5fea0a95af3b4cc96020b77 located in testdata/test_index1 can be loaded.
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
				if _, err := validateLayer(layer, rt.layerHashes[i]); err != nil {
					t.Fatalf("layers[%d] is invalid: %v", i, err)
				}
			}

		})
	}
}

// validateLayer checks if the digests and media type matches for the given layer.
func validateLayer(layer v1.Layer, layerHash v1.Hash) (int, error) {
	ld, err := layer.Digest()

	if err != nil {
		return 1, err
	}
	if got, want := ld, layerHash; got != want {
		return 1, fmt.Errorf("Digest(); got: %q want: %q", got, want)
	}

	mt, err := layer.MediaType()
	if err != nil {
		return 1, err
	}
	if got, want := mt, types.DockerLayer; got != want {
		return 1, fmt.Errorf("MediaType(); got: %q want: %q", got, want)
	}

	return 0, nil
}
