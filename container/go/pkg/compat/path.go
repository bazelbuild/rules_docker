package compat

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	v1 "github.com/google/go-containerregistry/pkg/v1"
)

// Path represents an MM intermediate image layout rooted in a file system path
type Path string

func (l Path) path(elem ...string) string {
	complete := []string{string(l)}
	return filepath.Join(append(complete, elem...)...)
}

// ImageIndex returns a ImageIndex for the Path.
func (l Path) ImageIndex() (v1.ImageIndex, error) {
	rawManifest, err := ioutil.ReadFile(l.path("manifest.json"))
	if err != nil {
		return nil, err
	}

	idx := &intermediateLayout{
		path:        l,
		rawManifest: rawManifest,
	}

	return idx, nil
}

func (l Path) Image(h v1.Hash) (v1.Image, error) {
	ii, err := l.ImageIndex()
	if err != nil {
		return nil, err
	}

	return ii.Image(h)
}

// FromPath reads an OCI image layout at path and constructs a layout.Path.
func FromPath(path string) (Path, error) {
	var err error
	_, err = os.Stat(filepath.Join(path, "manifest.json"))
	if err != nil {
		return "", err
	}

	_, err = os.Stat(filepath.Join(path, "config.json"))
	if err != nil {
		return "", err
	}

	_, err = os.Stat(filepath.Join(path, "digest"))
	if err != nil {
		return "", err
	}

	return Path(path), nil
}

func layerPathFromIndex(i int) string {
	return fmt.Sprintf("%03d.tar.gz", i)
}
