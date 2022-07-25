// Copyright 2015 The Bazel Authors. All rights reserved.
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
package utils

import (
	"fmt"
	"os"
)

// InitializeDockerConfig initialize the docker client config.
//
// If the user provided a client config directory, ensure it's a valid
// directory and instruct the keychain resolver to use it to look for the
// docker client config.
func InitializeDockerConfig(configDir string) error {
	const (
		errorPrefix = "failed to validate the Docker client config dir specified via --client-config-dir"
	)

	if configDir == "" {
		return nil
	}

	fi, err := os.Stat(configDir)
	if err != nil {
		return fmt.Errorf("%s: can't stat %q: %v", errorPrefix, configDir, err)
	}

	if !fi.IsDir() {
		return fmt.Errorf("%s: %q is not a directory", errorPrefix, configDir)
	}

	if err := os.Setenv("DOCKER_CONFIG", configDir); err != nil {
		return fmt.Errorf("can't set environment variable DOCKER_CONFIG: %v", err)
	}

	return nil
}
