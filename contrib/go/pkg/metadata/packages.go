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

// Package metadata provides functionality to store metadata about debian
// packages installed in a docker image layer.
package metadata

// PackageMetadata is the YAML entry for a single software package.
type PackageMetadata struct {
	// Name is the name of the software package.
	Name string `yaml:"name"`
	// Version is the version string of the software package.
	Version string `yaml:"version"`
}

// PackagesMetadata is the collection of software package metadata read from
// the input CSV file to be serialized into a YAML file.
type PackagesMetadata struct {
	// Packages is the list of software package entries read from the input
	// CSV file.
	Packages []PackageMetadata `yaml:"packages"`
}
