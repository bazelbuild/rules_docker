// Copyright 2016 The Bazel Authors. All rights reserved.
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
// Binary join_layers creates a Docker image tarball from a base image and a
// list of image layers.
package main

import (
	"flag"
	"log"

	"github.com/bazelbuild/rules_docker/container/go/pkg/utils"
)

var (
	outputTarball  = flag.String("output", "", "Path to the output image tarball.")
	tags           utils.ArrayStringFlags
	manifests      utils.ArrayStringFlags
	layers         utils.ArrayStringFlags
	sourceImages   utils.ArrayStringFlags
	stampInfoFiles utils.ArrayStringFlags
)

func main() {
	flag.Var(&tags, "tag", "One or more fully qualified tag names along with the layer they tag in tag=layer format. e.g., --tag ubuntu=deadbeef --tag gcr.io/blah/debian=baadf00d.")
	flag.Var(&manifests, "manifest", "One or more fully qualified tag names along with the associated manifest in tag=manifest format. e.g., --manifest ubuntu=deadbeef --manifest gcr.io/blah/debian=baadf00d.")
	flag.Var(&layers, "layer", "One or more layers with the following comma separated values (Diff ID, Blob sum, Uncompressed layer tarball, Compressed layer tarball). e.g., --layer diffa,hash,layer1.tar,layer1.tar.gz.")
	flag.Var(&sourceImages, "source_image", "One or more image tarballs for images from which the output image of this binary may derive. e.g., --source_image imag1.tar --source_image image2.tar.")
	flag.Var(&stampInfoFiles, "stamp_info_file", "Path to one or more Bazel stamp info file with key value pairs for substitution.")
	flag.Parse()
	log.Println("tags", tags)
	log.Println("manifests", manifests)
	log.Println("layers", layers)
	log.Println("source images", sourceImages)
	log.Println("stamp info files", stampInfoFiles)
}
