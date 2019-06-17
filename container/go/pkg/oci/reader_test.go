package oci

import (
	"testing"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"github.com/google/go-containerregistry/pkg/v1/validate"
)

// This test index is pulled by puller.go from gcr.io/distroless/base@sha256:edc3643ddf96d75032a55e240900b68b335186f1e5fea0a95af3b4cc96020b77
var (
	manifestDigest = v1.Hash{
		Algorithm: "sha256",
		Hex:       "edc3643ddf96d75032a55e240900b68b335186f1e5fea0a95af3b4cc96020b77",
	}
	configDigest = v1.Hash{
		Algorithm: "sha256",
		Hex:       "a0cfcd4cc98a67def7ce9a0c7644d1c415d56d6d44c4a079a447f7eafb253048",
	}
	layer1Hash = v1.Hash{
		Algorithm: "sha256",
		Hex:       "1558143043601a425aa864511da238799b57fcf7d062d47044f6ddd0e04fe99a",
	}
	layer2Hash = v1.Hash{
		Algorithm: "sha256",
		Hex:       "5f5edd681dcbc3a4a9df93e200e59e1708031e65b2299970eabdc91a78cc8234",
	}
	testPath = "test_data/test_index1"
)

// TestRead checks the v1.Image outputted by <Read> by validating its manifest, layers and configs.
func TestRead(t *testing.T) {
	img, err := Read(testPath)
	if err != nil {
		t.Fatalf("Read(%s): %v", testPath, err)
	}

	if err := validate.Image(img); err != nil {
		t.Errorf("validate.Image(): %v", err)
	}

	mt, err := img.MediaType()
	if err != nil {
		t.Errorf("img.MediaType(): %v", err)
	} else if got, want := mt, types.DockerManifestSchema2; got != want {
		t.Errorf("img.MediaType(); want: %v got: %v", want, got)
	}

	cfg, err := img.LayerByDigest(configDigest)
	if err != nil {
		t.Fatalf("LayerByDigest(%s): %v", configDigest, err)
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
		t.Errorf("ConfigName(); want: %v got: %v", want, got)
	}

	layers, err := img.Layers()
	if err != nil {
		t.Fatalf("img.Layers(): %v", err)
	}

	layer1Digest, err := layers[0].Digest()
	if err != nil {
		t.Fatalf("layers[0].Digest(): %v", err)
	}
	if got, want := layer1Digest, layer1Hash; got != want {
		t.Fatalf("layers[0].Digest(); want: %q got: %q", want, got)
	}

	layer2Digest, err := layers[1].Digest()
	if err != nil {
		t.Fatalf("layers[1].Digest(): %v", err)
	}
	if got, want := layer2Digest, layer2Hash; got != want {
		t.Fatalf("layers[1].Digest(); want: %q got: %q", want, got)
	}

	mediaType, err := layers[0].MediaType()
	if err != nil {
		t.Fatalf("img.Layers(): %v", err)
	}

	if got, want := mediaType, types.DockerLayer; got != want {
		t.Fatalf("layers[0].MediaType(); want: %q got: %q", want, got)
	}
}
