package oci

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path"
	"strings"
	"testing"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/layout"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/validate"
)

var (
	blob     = "/blobs/"
	index    = "/index.json"
	ocif     = "/oci-layout"
	testPath = "testdata/test_write1"
)

var testCases = []struct {
	// name is the name of the test case
	name string
	// dataPath is where the test data is found
	dataPath string
	// the sha code for the manifest
	shaPath string
	// content is the oci layout content where the key is the file path and value is sha256 sum
	content map[string]v1.Hash
}{
	{
		"alpine_linux",
		"testdata/test_write1/small_linux.tar",
		"sha256/9a96f3888ebad00d46bca04ccb591e70d091624835998668af551f48512d9b5c",
		map[string]v1.Hash{
			"blobs/sha256/9a96f3888ebad00d46bca04ccb591e70d091624835998668af551f48512d9b5c": v1.Hash{Algorithm: "sha256", Hex: "9a96f3888ebad00d46bca04ccb591e70d091624835998668af551f48512d9b5c"},
			"index.json": v1.Hash{Algorithm: "sha256", Hex: "ce6ed2e6817add8a5a0e94f4c2ac00360c7ca2cc98c4972b86530f14de622508"},
			"oci-layout": v1.Hash{Algorithm: "sha256", Hex: "b66dbb27a73334db6ac9c030475837bd7f4472d835c72b2360534b203edce6cb"},
		},
	},
}

// TestWrite checks to ensure that the v1.Image written is in OCI format by validating image output format and content
func TestWrite(t *testing.T) {
	for _, wt := range testCases {
		t.Run(wt.name, func(t *testing.T) {
			tmp, err := ioutil.TempDir("", "write-oci-index-test")
			if err != nil {
				t.Errorf("Write(%s): %v", os.TempDir(), err)
			}

			defer os.RemoveAll(tmp)

			img, err := tarball.ImageFromPath(wt.dataPath, nil)
			if err != nil {
				t.Errorf("error loading image from testdata: %v", err)
			}

			if err := assertImageIndexValid(tmp, img); err != nil {
				t.Errorf("image written is not a valid index: %v", err)
			}

			if err = assertOCIFormat(tmp, img, wt.content, wt.shaPath); err != nil {
				t.Errorf("image is not in oci format: %v", err)
			}
		})
	}
}

func assertImageIndexValid(tmp string, img v1.Image) error {
	if err := Write(img, tmp); err != nil {
		return fmt.Errorf("error writing image to temp path %s", tmp)
	}

	written, err := layout.ImageIndexFromPath(tmp)
	if err != nil {
		return fmt.Errorf("failed to write image to temp path %s", tmp)
	}

	if err := validate.Index(written); err != nil {
		return fmt.Errorf("validate.Index() = %v", err)
	}

	return nil
}

func assertOCIFormat(tmp string, img v1.Image, content map[string]v1.Hash, shaPth string) error {
	if err := Write(img, "/usr/local/google/home/xwinxu/Desktop/temp/temp"); err != nil {
		return fmt.Errorf("error writing image to temp path %s", tmp)
	}

	// validate that the contents of blobs/ were written in the following format:
	// Top level:
	//     oci-layout, index.json, blobs/
	// Under blobs/, for each image:
	// 	   one file for each layer, config blob, and manifest blob
	blobs := tmp + blob
	blob, err := os.Stat(blobs)
	if err != nil {
		return fmt.Errorf("could not obtain stat; blob doesn't exist: %v", err)
	}
	if os.IsNotExist(err) {
		return fmt.Errorf("wrong OCI output format; got: %v, missing: %s", err, blob)
	}
	if !blob.IsDir() {
		return fmt.Errorf("failed to write blobs/ directory to %s", tmp)
	}
	f, err := os.Open(blobs)
	if err != nil {
		return fmt.Errorf("failed to open directory blobs: %v", err)
	}
	defer f.Close()
	_, err = f.Readdirnames(1)
	if err == io.EOF {
		return fmt.Errorf("blobs directory is empty: %v", err)
	}
	if err = compareSHA(path.Join(blobs, shaPth), "blobs file at "+shaPth, content["blobs/sha256/9a96f3888ebad00d46bca04ccb591e70d091624835998668af551f48512d9b5c"].Hex); err != nil {
		return fmt.Errorf("sha256 hex code did not match %v", err)
	}

	// validate the index.json file
	idx, err := os.Stat(path.Join(tmp, index))
	if err != nil {
		return fmt.Errorf("could not obtain stat: %v", err)
	}

	if os.IsNotExist(err) {
		return fmt.Errorf("wrong OCI output format; got: %v, missing: %s", err, index)
	}
	if idx.Size() == 0 {
		return fmt.Errorf("error occured: empty index.json, size: %d", idx.Size())
	}
	if err = compareSHA(path.Join(tmp, index), "oci-layout", content["index.json"].Hex); err != nil {
		return fmt.Errorf("sha256 hex code did not match, %v", err)
	}

	// validate the oci-layout file
	oci, err := os.Stat(tmp + ocif)
	if err != nil {
		return fmt.Errorf("could not obtain stat: %v", err)
	}
	if os.IsNotExist(err) {
		return fmt.Errorf("wrong OCI output format; got: %v, missing: %s", err, index)
	}
	if oci.Size() == 0 {
		return fmt.Errorf("error occured: empty oci-layout, size: %d", oci.Size())
	}
	if err = compareSHA(path.Join(tmp, ocif), "oci-layout", content["oci-layout"].Hex); err != nil {
		return fmt.Errorf("sha256 hex code did not match, %v", err)
	}

	return nil
}

// compares the SHA256 value of src file to example
func compareSHA(src, tag, want string) error {
	f, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("failed to open %s file", tag)
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return fmt.Errorf("sha256 hashing failed: %v", err)
	}
	got := hex.EncodeToString(h.Sum(nil))
	if strings.Compare(got, want) != 0 {
		return fmt.Errorf("sha256 hex code did not match, wanted: %s got: %s", want, got)
	}

	return nil
}
