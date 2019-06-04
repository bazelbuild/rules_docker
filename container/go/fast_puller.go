package main

import (
	"flag"
	"log"
)

var (
	name = flag.String("name",
		"",
		"The name of the docker image to pull and save. Supports fully-qualified tag or digest references.",
	)

	directory = flag.String("directory",
		"",
		"Where to save the images files",
	)

	configFlag = flag.String("configFlag",
		"",
		"The path to the directory where the client configuration files are located. Overiddes the value from DOCKER_CONFIG",
	)

	cache = flag.String("cache",
		"",
		"Image's files cache directory.",
	)
)

func main() {
	flag.Parse()
	log.Println("Running the Image Config & Manifest Extractor.")
	log.Println("Command line arguments:")
	log.Printf("-imageTar: %q", *name)
	log.Printf("-outConfig: %q", *directory)
	log.Printf("-outManifest: %q", *configFlag)
	log.Printf("-outManifest: %q", *cache)

	// mandatory arguments
	if *name == "" {
		log.Fatalln("Required option -name was not specified.")
	}

	if *directory == "" {
		log.Fatalln("Required option -directory was not specified.")
	}
}
