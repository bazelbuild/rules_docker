package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/remote"
)

type stringSliceFlag []string

func (i *stringSliceFlag) String() string {
	return fmt.Sprintf("%q", *i)
}

func (i *stringSliceFlag) Set(value string) error {
	*i = append(*i, value)
	return nil
}

func pushImage(dstRef, configFile string, layerFilePaths, layerDigestPaths []string) error {
	dstTag, err := name.NewTag(dstRef, name.WeakValidation)
	if err != nil {
		return fmt.Errorf("parsing tag %q: %v", dstRef, err)
	}

	// Auth (through docker's config file)
	dstAuth, err := authn.DefaultKeychain.Resolve(dstTag.Context().Registry)
	if err != nil {
		return fmt.Errorf("getting creds for %q: %v", dstTag, err)
	}

	img, err := fromDisk(configFile, layerFilePaths, layerDigestPaths)
	if err != nil {
		return err
	}

	// Push
	opts := remote.WriteOptions{}
	if err := remote.Write(dstTag, img, dstAuth, http.DefaultTransport, opts); err != nil {
		return fmt.Errorf("writing image %q: %v", dstTag, err)
	}

	return nil
}

func readClosers(paths []string) (readers []io.ReadCloser) {
	for _, p := range paths {
		f, err := os.Open(p)
		if err != nil {
			log.Fatalf("opening file %q: %v", p, err)
		}
		readers = append(readers, f)
	}
	return
}

func main() {
	// These flag values must be compatible with the expectations at
	// https://github.com/bazelbuild/rules_docker/blob/4338ecf45187a848d55a3651b6c1d70fe1ef6cce/container/push-tag.sh.tpl#L26
	dstName := flag.String("name", "", "Destination reference of the image")
	configFilePath := flag.String("config", "", "Docker config file")

	var (
		layerFilePaths   stringSliceFlag
		layerDigestPaths stringSliceFlag
		stampFiles       stringSliceFlag
	)
	flag.Var(&layerFilePaths, "layer", "Paths to compressed image layers")
	flag.Var(&layerDigestPaths, "digest", "Paths to files containing layer digests")
	flag.Var(&stampFiles, "stamp-info-file", "Bazel stamp variable files")

	_ = flag.String("format", "", "Unused")
	flag.Parse()

	dstRef := stampReference(*dstName, readClosers(stampFiles))
	if err := pushImage(dstRef, *configFilePath, layerFilePaths, layerDigestPaths); err != nil {
		log.Fatal(err)
	}
}
