package utils

import (
	"bufio"
	"bytes"
	"fmt"
	"html/template"
	"os"
	"strings"

	"github.com/bazelbuild/rules_docker/container/go/pkg/compat"
	"github.com/bazelbuild/rules_docker/container/go/pkg/oci"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/pkg/errors"
)

// ArrayStringFlags are defined for string flags that may have multiple values.
type ArrayStringFlags []string

// Returns the concatenated string representation of the array of flags.
func (f *ArrayStringFlags) String() string {
	return fmt.Sprintf("%v", *f)
}

// Get returns an empty interface that may be type-asserted to the underlying
// value of type bool, string, etc.
func (f *ArrayStringFlags) Get() interface{} {
	return ""
}

// Set appends value the array of flags.
func (f *ArrayStringFlags) Set(value string) error {
	*f = append(*f, value)
	return nil
}

// ReadImage returns a v1.Image after reading an legacy layout, an OCI layout or a Docker tarball from src.
func ReadImage(src, format string) (v1.Image, error) {
	if format == "oci" {
		return oci.Read(src)
	}
	if format == "legacy" {
		return compat.Read(src)
	}
	if format == "docker" {
		return tarball.ImageFromPath(src, nil)
	}

	return nil, errors.Errorf("unknown image format %q", format)
}

// TODO: REMOVE these two functions copied from Winnie's PR, refactor after her PR is merged. https://github.com/bazelbuild/rules_docker/pull/973
type formattedString map[string]interface{}

// formateWithMap takes all variables of format {{.VAR}} in the input string `format`
// and replaces it according to the map of parameters to values in `params`.
func formatWithMap(format string, params formattedString) string {
	msg := &bytes.Buffer{}
	template.Must(template.New("").Parse(format)).Execute(msg, params)
	return msg.String()
}

// Stamp provides the substitutions of variables inside {} using info in file pointed to
// by stampInfoFile.
func Stamp(inp string, stampInfoFile []string) (string, error) {
	if len(stampInfoFile) == 0 || inp == "" {
		return inp, nil
	}
	formatArgs := make(map[string]interface{})
	for _, infofile := range stampInfoFile {
		f, err := os.Open(infofile)
		if err != nil {
			return "", errors.Wrapf(err, "failed to open file %s", infofile)
		}
		defer f.Close()
		// scanner reads line by line and discards '\n' character already
		scanner := bufio.NewScanner(f)
		var temp []string
		for scanner.Scan() {
			temp = strings.Split(scanner.Text(), " ")
			key, val := temp[0], temp[1]
			if _, ok := formatArgs[key]; ok {
				fmt.Printf("WARNING: Duplicate value for key %s: using %s", key, val)
			}
			formatArgs[key] = val
		}
		if err = scanner.Err(); err != nil {
			return "", errors.Wrapf(err, "failed to read line from file %s", infofile)
		}
	}
	// do string manipulation in order to mimic python string format.
	// specifically, replace '{' with '{{.' and '}' with '}}'.
	inpReformatted := strings.ReplaceAll(inp, "{", "{{.")
	inpReformatted = strings.ReplaceAll(inpReformatted, "}", "}}")
	return formatWithMap(inpReformatted, formattedString(formatArgs)), nil
}
