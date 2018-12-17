// Copyright 2017 The Bazel Authors. All rights reserved.
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

// This file is used to test the launcher attr of container_image
package main

import (
	"flag"
	"fmt"
	"os"
	"syscall"
)

func main() {
	var extraEnv stringSlice
	flag.Var(&extraEnv, "env", "Append to the environment of the launched binary. May be specified multiple times. (eg --env=VAR_NAME=value)")
	flag.Parse()
	envv := append(os.Environ(), extraEnv...)
	argv := flag.Args()
	err := syscall.Exec(argv[0], argv, envv)
	if err != nil {
		panic(err)
	}
}

type stringSlice []string

func (i *stringSlice) String() string {
	return fmt.Sprintf("%s", *i)
}

func (i *stringSlice) Set(v string) error {
	*i = append(*i, v)
	return nil
}
