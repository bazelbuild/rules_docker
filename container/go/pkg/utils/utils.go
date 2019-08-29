package utils

import (
	"fmt"
	"path/filepath"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
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

// ReadImage returns a v1.Image after reading an image in OCI or Docker format.
func ReadImage(imgConfig, imgTarball string, layersPath []string) (v1.Image, error) {
	if imgTarball != "" && filepath.Ext(imgTarball) != ".tar" {
		return nil, errors.Errorf("got invalid image tarball file, got %s, want path to file with extension .tar", imgTarball)
	}
	if imgTarball != "" {
		return tarball.ImageFromPath(imgTarball, nil)
	}

	layers := []compat.LayerOpts{}
	for _, l := range layersPath {
		layers = append(layers, compat.LayerOpts{
			Type: types.DockerLayer,
			Path: l,
		})
	}
	return compat.Read(imgConfig, layers)
}
