package puller

import (
	"fmt"
	"log"

	v1 "github.com/google/go-containerregistry/pkg/v1"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/cache"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

const iWasADigestTag = "i-was-a-digest"

// Pull the image with given <imgName> to destination <dstPath> with optional
// cache files and required platform specifications.
func pull(imgName, dstPath, cachePath string, platform v1.Platform) {
	// Get a digest/tag based on the name
	ref, err := name.ParseReference(imgName)
	if err != nil {
		log.Fatalf("parsing tag %q: %v", imgName, err)
	}
	log.Printf("Pulling %v", ref)

	// Fetch the image with desired cache files and platform specs
	i, err := remote.Image(ref, remote.WithAuthFromKeychain(authn.DefaultKeychain), remote.WithPlatform(platform))
	if err != nil {
		log.Fatalf("reading image %q: %v", ref, err)
	}
	if cachePath != "" {
		i = cache.Image(i, cache.NewFilesystemCache(cachePath))
	}

	// WriteToFile wants a tag to write to the tarball, but we might have
	// been given a digest.
	// If the original ref was a tag, use that. Otherwise, if it was a
	// digest, tag the image with :i-was-a-digest instead.
	tag, ok := ref.(name.Tag)
	if !ok {
		d, ok := ref.(name.Digest)
		if !ok {
			log.Fatal("ref wasn't a tag or digest")
		}
		s := fmt.Sprintf("%s:%s", d.Repository.Name(), iWasADigestTag)
		tag, err = name.NewTag(s)
		if err != nil {
			log.Fatalf("parsing digest as tag (%s): %v", s, err)
		}
	}

	if err := tarball.WriteToFile(dstPath, tag, i); err != nil {
		log.Fatalf("writing image %q: %v", dstPath, err)
	}
}
