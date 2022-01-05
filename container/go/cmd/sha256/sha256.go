// Portable SHA256 tool.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"io"
	"io/ioutil"
	"log"
	"os"
)

func main() {
	flag.Parse()
	if len(os.Args) != 3 {
		log.Fatalf("Usage: %s input output", os.Args[0])
	}

	inputfile, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatalf("error reading %s: %s", os.Args[1], err)
	}

	h := sha256.New()
	if _, err := io.Copy(h, inputfile); err != nil {
		log.Fatalf("error reading %s: %s", os.Args[1], err)
	}

	if err := inputfile.Close(); err != nil {
		log.Fatalf("error reading %s: %s", os.Args[1], err)
	}
	sum := h.Sum(nil)
	hexSum := hex.EncodeToString(sum)

	if err := ioutil.WriteFile(os.Args[2], []byte(hexSum), 0666); err != nil {
		log.Fatalf("error writing %s: %s", os.Args[2], err)
	}
}
