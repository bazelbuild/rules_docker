package utils

import (
	"fmt"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/pkg/errors"
)

// ArrayFlags are defined for flags that may have multiple values.
type ArrayFlags []string

// Returns the concatenated string representation of the array of flags.
func (f *ArrayFlags) String() string {
	return fmt.Sprintf("%v", *f)
}

// Set appends value the array of flags.
func (f *ArrayFlags) Set(value string) error {
	*f = append(*f, value)
	return nil
}

// ReadImage returns a v1.Image after reading an legacy layout, an OCI layout or a Docker tarball from src.
func ReadImage(src, format string) (v1.Image, error) {
	if format == "oci" {
		return oci.Read(src)
	}
	if format == "legacy" {
		return compat.Read(src)
	}
	if format == "docker" {
		return tarball.ImageFromPath(src, nil)
	}

	return nil, errors.Errorf("unknown image format %q", format)
}
