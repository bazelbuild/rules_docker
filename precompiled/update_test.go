package precompiled

import (
	"fmt"
	"bytes"
	"crypto/sha256"
	"io"
	"os"
	"testing"
	"path/filepath"
	"runtime"
)

func resource(name string) (string, error) {
	src := os.Getenv("TEST_SRCDIR")
	workspace := os.Getenv("TEST_WORKSPACE")
	return filepath.EvalSymlinks(fmt.Sprintf("%s/%s/%s", src, workspace, name))
}

func precompiledResource(name string) (string, error) {
  return resource(fmt.Sprintf("precompiled/%s_%s/%s", runtime.GOOS, runtime.GOARCH, name))
}

func hashFile(name string) ([]byte, error) {
	f, err := os.Open(name)
	if err != nil {
		return []byte{}, err
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return []byte{}, err
	}
	return h.Sum(nil), nil
}

func filesAreEqual(left, right string) (bool, error) {
	leftHash, err := hashFile(left)
	if err != nil {
		return false, err
	}
	rightHash, err := hashFile(right)
	if err != nil {
		return false, err
	}
	return bytes.Compare(leftHash, rightHash) == 0, nil
}

func TestBinariesUpdated(t *testing.T) {
	
	precompiledLoader, err := precompiledResource("loader")
	if err != nil {
		t.Fatalf("Failed to resolve precompiled loader: %v", err)
	}
	compiledLoader, err := resource("container/go/cmd/loader/loader_/loader")
	if err != nil {
		t.Fatalf("Failed to resolve compiled loader: %v", err)
	}
	t.Logf("Comparing %s to %s", precompiledLoader, compiledLoader)
	loader, err := filesAreEqual(precompiledLoader, compiledLoader)

	if err != nil {
		t.Fatalf("Failed to hash files: %v", err)
	}
	if loader {
		t.Logf("Loader is up to date")
	} else {
		t.Errorf("Loader is not up to date.")
	}
}
