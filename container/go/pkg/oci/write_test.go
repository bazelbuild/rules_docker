package oci

import (
	"io"
	"io/ioutil"
	"os"
	"testing"

	"github.com/google/go-containerregistry/pkg/v1/layout"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/validate"
)

var (
	blob     = "/blobs/"
	index    = "/index.json"
	oci      = "/oci-layout"
	testPath = "testdata/test_write_alp"
)

var testCases = []struct {
	// name is the name of the test case
	name string
	// dataPath is where the test data is found
	dataPath string
	// content is the oci layout content where the key is the file path and value is sha256 sum
	content map[string]string
}{}

func TestWrite(t *testing.T) {
	tmp, err := ioutil.TempDir("", "write-oci-index-test")
	if err != nil {
		t.Fatalf("Write(%s): %v", os.TempDir(), err)
	}

	defer os.RemoveAll(tmp)

	img, err := tarball.ImageFromPath("testdata/test_write1/test_alpine.tar", nil)
	if err != nil {
		t.Fatalf("error loading image from testdata: %v", err)
	}

	if err := Write(img, tmp); err != nil {
		t.Fatalf("error writing image to temp path %s", tmp)
	}

	written, err := layout.ImageIndexFromPath(tmp)
	if err != nil {
		t.Fatalf("failed to write image to temp path %s", tmp)
	}

	if err := validate.Index(written); err != nil {
		t.Fatalf("validate.Index() = %v", err)
	}
}

func TestWriteOCIFormat(t *testing.T) {
	tmp, err := ioutil.TempDir("", "write-oci-index-test")
	if err != nil {
		t.Fatalf("Write(%s): %v", os.TempDir(), err)
	}

	defer os.RemoveAll(tmp)

	img, err := tarball.ImageFromPath("testdata/test_write1/test_alpine.tar", nil)
	if err != nil {
		t.Fatalf("error opening image index from path %s: %v", testPath, err)
	}

	if err := Write(img, tmp); err != nil {
		t.Fatalf("error writing image to temp path %s", tmp)
	}

	// check that the contents were written in the following format:
	// Top level:
	//     oci-layout, index.json, blobs/
	// Under blobs/, for each image:
	// 	   one file for each layer, config blob, and manifest blob
	blobs := tmp + blob
	blob, err := os.Stat(blobs)
	if err != nil {
		t.Fatalf("could not obtain stat; blob doesn't exist: %v", err)
	}
	if os.IsNotExist(err) {
		t.Fatalf("wrong OCI output format; got: %v, missing: %s", err, blob)
	} else {
		if !blob.IsDir() {
			t.Fatalf("failed to write blobs/ directory to %s", tmp)
		}
		f, err := os.Open(blobs)
		if err != nil {
			t.Fatalf("failed to open directory blobs: %v", err)
		}
		defer f.Close()
		_, err = f.Readdirnames(1)
		if err == io.EOF {
			t.Fatalf("blobs directory is empty: %v", err)
		}
	}

	idx, err := os.Stat(tmp + index)
	if err != nil {
		t.Fatalf("could not obtain stat: %v", err)
	}
	if os.IsNotExist(err) {
		t.Fatalf("wrong OCI output format; got: %v, missing: %s", err, index)
	} else {
		// Check if hash of index.json == 3a3065e526169cf1ff3418330ca040cb2a17ea99f78af3125f797cbfa269d8f3

		if idx.Size() == 0 {
			t.Fatalf("error occured: empty index.json, size: %d", idx.Size())
		}
	}

	oci, err := os.Stat(tmp + oci)
	if err != nil {
		t.Fatalf("could not obtain stat: %v", err)
	}
	if os.IsNotExist(err) {
		t.Fatalf("wrong OCI output format; got: %v, missing: %s", err, index)
	} else {
		if oci.Size() == 0 {
			t.Fatalf("error occured: empty oci-layout, size: %d", oci.Size())
		}
	}
}

func TestWriteOCIContent(t *testing.T) {
	tmp, err := ioutil.TempDir("", "write-oci-index-test")
	if err != nil {
		t.Fatalf("Write(%s): %v", os.TempDir(), err)
	}

	defer os.RemoveAll(tmp)

	img, err := tarball.ImageFromPath("testdata/test_write1/test_alpine.tar", nil)
	if err != nil {
		t.Fatalf("error opening image index from path %s: %v", testPath, err)
	}

	if err := Write(img, tmp); err != nil {
		t.Fatalf("error writing image to temp path %s", tmp)
	}

	// files, err := ioutil.ReadDir(tmp)
	// if err != nil {
	// 	log.Fatalf("failed to read temporary directory: %v", err)
	// }
	// for _, file := range files {
	// 	fmt.Println(file.Name())
	// }
}
