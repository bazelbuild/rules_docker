// Package imagetest contains integration tests for the container_* rules.
package imagetest

import (
	"fmt"
	"os"
)

// This file primarily contains helper functions for utilities that have separate implementations
// in the internal and external versions of rules_docker.

// resolvePath converts a filePath from a path relative to the rules_docker repo to the actual
// runfile path that can be used to actually open the file.
// Example input path: testdata/files_base.tar referring to the image tarball built by
// //testdata:files_base.

func resolvePath(filePath string) string {
	// Advanced NP Hard algorithm to figure out the Bazel runfile directory ;).
	return fmt.Sprintf("%s/%s/%s", os.Getenv("TEST_SRCDIR"), os.Getenv("TEST_WORKSPACE"), filePath)
}
