package main

import (
	"bufio"
	"io"
	"strings"
)

// oldnew returns a slice of strings to be used with strings.NewReplacer
func oldnew(r io.ReadCloser, s []string) []string {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		line := scanner.Text()
		tokens := strings.SplitN(line, " ", 2)
		if len(tokens) == 0 {
			continue
		}
		key := "{" + tokens[0] + "}"

		var val string
		if len(tokens) > 1 {
			val = tokens[1]
		}
		s = append(s, key, val)
	}
	_ = r.Close()
	return s
}

func stampReference(dstName string, stampFiles []io.ReadCloser) string {
	var replacements []string
	for _, stampFile := range stampFiles {
		replacements = oldnew(stampFile, replacements)
	}

	r := strings.NewReplacer(replacements...)
	return r.Replace(dstName)
}
