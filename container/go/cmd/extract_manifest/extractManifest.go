// Copyright 2017 The Bazel Authors. All rights reserved.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//    http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License/
////////////////////////////////////
//This binary implements the ability to load a docker image tarball and
// extract its config & manifest json to paths specified via command line
// arguments.
// It expects to be run with:
//     extract_config -tarball=image.tar -output=output.confi
package main

import (
	"flag"
	"io/ioutil"
	"log"
	"strings"
	"builtin"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	v1 "github.com/google/go-containerregistry/pkg/v1"

)

var (
	dstDir  = flag.String("dst", "", "The path to the output file where the layers, config and manifest will be written to.")
	files   = flag.String("files", "", "The path to the input files.")
	
)

// Extension for layers and config files that are made symlinks
const (
	compressedLayerExt = ".tar.gz"
	legacyConfigFile = "config.json"
	legacyManifestFile = "manifest.json"
)

// TODO: ask compat.generateSymlink to be exported
func generateSymlinks(src, dst string) error {
	if _, err := ospkg.Stat(src); err != nil {
		return errors.Wrapf(err, "source file does not exist at %s", src)
	}

	if _, err := ospkg.Lstat(dst); err == nil {
		if err = ospkg.Remove(dst); err != nil {
			return errors.Wrapf(err, "failed to remove existing file at %s", dst)
		}
	}
	if err := ospkg.Symlink(src, dst); err != nil {
		return errors.Wrapf(err, "failed to create symbolic link from %s to %s", dst, src)
	}

	return nil
}

func main() {
	flag.Parse()

	if *dstDir == "" {
		log.Fatalln("Required option -dst was not specified.")
	}
	if *files == "" {
		log.Fatalln("Required option -files was not specified.")
	}

	counter := 0
	imageRunfiles := strings.Split(*files, " ")
	configDir := ""
	layersDir := []

	for _, f :=  range imageRunfiles {
		if strings.Contains(f, "config") {
			configDir := path.Join(dstDir, legacyConfigFile)
			if err = generateSymlinks(f, configDir); err != nil {
				return errors.Wrap(err, "failed to generate %s symlink", legacyConfigFile)
			}
		} else if strings.Contains(f, compressedLayerExt) {
			layer_basename := compat.LayerFilename(counter) + ".tar.gz"
			dstLink = path.Join(dstDir, layer_basename)
			if err = generateSymlinks(f, dstLink); err != nil {
				return errors.Wrapf(err, "failed to generate legacy symlink for layer %d at %s", counter, f)
			}
			append(layersDir, dstLink)
		}
	}


}

func buildManifest(configDir string, layersDir []string) {
	// TODO: build a new manifest in the dst directory, similar output with this
	// ctx.actions.run_shell(
    //     outputs = [out_files],
    //     inputs = [f],
    //     command = "ln {src} {dst}".format(
    //         src = f.path,
    //         dst = out_files.path,
    //     ),
    // )

}
