// Copyright 2020 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
////////////////////////////////////////////////
// This package performs gzip operations.

package main

import (
	"compress/gzip"
	"flag"
	"io"
	"log"
	"os"
)

var (
	src        = flag.String("src", "", "The source location of the file to zip/unzip.")
	dst        = flag.String("dst", "", "The destination location of the file, after zip/unzip.")
	decompress = flag.Bool("decompress", false, "If true, perform gunzip. If false, gzip.")
	fast       = flag.Bool("fast", false, "If true, use the fastest compression level.")
)

func main() {
	flag.Parse()

	if *src == "" {
		log.Fatalln("Required option -src was not specified.")
	}

	if *dst == "" {
		log.Fatalln("Required option -dst was not specified.")
	}

	var copy_from io.Reader
	var copy_to io.Writer

	f, err := os.Open(*src)
	if err != nil {
		log.Fatalf("Unable to read input file: %v", err)
	}
	t, err := os.Create(*dst)
	if err != nil {
		log.Fatalf("Unable to create output file: %v", err)
	}

	if *decompress {
		zr, err := gzip.NewReader(f)
		if err != nil {
			log.Fatalf("Unable to read: %v", err)
		}
		defer func() {
			if err := zr.Close(); err != nil {
				log.Fatalf("Unable to close gzip reader: %v", err)
			}
		}()
		copy_from = zr
		copy_to = t
	} else {
		level := gzip.DefaultCompression
		if *fast {
			level = gzip.BestSpeed
		}
		zw, err := gzip.NewWriterLevel(t, level)
		if err != nil {
			log.Fatalf("Unable to create gzip writer: %v", err)
		}
		defer func() {
			if err := zw.Close(); err != nil {
				log.Fatalf("Unable to close gzip writer: %v", err)
			}
		}()
		copy_from = f
		copy_to = zw
	}
	if _, err := io.Copy(copy_to, copy_from); err != nil {
		log.Fatalf("Unable to perform the gzip operation from %q to %q: %v", *src, *dst, err)
	}
}
