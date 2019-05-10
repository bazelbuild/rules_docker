package main

import (
	"flag"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"log"
)

var (
	imageTar    = flag.String("imageTar", "", "The path to the Docker image tarball to extract the config & manifest for.")
	outConfig   = flag.String("outConfig", "", "Path to the output file where the image config will be written to.")
	outManifest = flag.String("outManifest", "", "Path to the output file where the image manifest will be written to.")
)

func main() {
	flag.Parse()
	log.Println("Running the Image Config & Manifest Extractor.")
	log.Println("Command line arguments:")
	log.Printf("-imageTar: %q", *imageTar)
	log.Printf("-outConfig: %q", *outConfig)
	log.Printf("-outManifest: %q", *outManifest)

	if *imageTar == "" {
		log.Fatalln("Required option -imageTar was not specified.")
	}
	if *outConfig == "" {
		log.Fatalln("Required option -outConfig was not specified.")
	}
	if *outManifest == "" {
		log.Fatalln("Required option -outManifest was not specified.")
	}
	img, err := tarball.ImageFromPath(*imageTar, nil)
	if err != nil {
		log.Fatalf("Unable to load docker image from %s: %v", *imageTar, err)
	}
	l, err := img.Layers()
	if err != nil {
		log.Fatalf("Unable to obtain layers from docker image loaded from %s: %v", *imageTar, err)
	}
	d, err := img.Digest()
	if err != nil {
		log.Fatalf("Unable to determine digest of docker image loaded from %s: %v", *imageTar, err)
	}
	log.Printf("Successfully loaded docker image from %s with %d layers, digest %s.", *imageTar, len(l), d)

	// TODO (suvanjan): Actually write the config & manifest here.

	log.Println("Image Config & Manifest Extractor was successful.")
}
