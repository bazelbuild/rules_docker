// This binary pulls images from a Docker Registry.
// Unlike regular docker pull, the format this package uses is proprietary.

package main

import (
	"flag"
	"log"
)

var (
	name            = flag.String("name", "", "The name of the docker image to pull and save. Supports fully-qualified tag or digest references.")
	directory       = flag.String("directory", "", "Where to save the images files.")
	clientConfigDir = flag.String("clientConfigDir", "", "The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG.")
	cache           = flag.String("cache", "", "Image's files cache directory.")
	threads         = 8
)

func main() {
	flag.Parse()
	log.Println("Running the Image Puller to pull images from a Docker Registry...")
	log.Println("Command line arguments:")
	log.Printf("-name: %q", *name)
	log.Printf("-directory: %q", *directory)
	log.Printf("-clientConfigDir: %q", *clientConfigDir)
	log.Printf("-cache: %q", *cache)

	if *name == "" {
		log.Fatalln("Required option -name was not specified.")
	}
	if *directory == "" {
		log.Fatalln("Required option -directory was not specified.")
	}

	log.Printf("Successfully pulled image %q into %q", *name, *directory)
}
