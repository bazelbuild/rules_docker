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

// path returns a full directory of this path concatenated with other <elem> paths. 
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

// Image returns the image with hash <h> in this Path.
func (l Path) Image(h v1.Hash) (v1.Image, error) {
	ii, err := l.ImageIndex()
	if err != nil {
		return nil, err
	}

	return ii.Image(h)
}

// FromPath reads an MM intermediate image index at path and constructs a layout.Path.
// Naively validates this is a valid intermediate layout by checking digest, config.json, and manifest.json exist. 
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

// Return the filename for layer at index i in the layers array in manifest.json.
// Assume the layers are padded to three digits, e.g., the first layer is named 000.tar.gz.
func layerFilename(i int) string {
	return fmt.Sprintf("%03d.tar.gz", i)
}
