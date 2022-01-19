// Copyright 2022 The Bazel Authors. All rights reserved.
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
//////////////////////////////////////////////////////////////////////
// This binary computes SHA256 for //skylib:hash.bzl
//
// Drop-in replacement for @bazel_tools//tools/build_defs/hash:sha256.py
// See: https://github.com/bazelbuild/bazel/blob/master/tools/build_defs/hash/sha256.py
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
