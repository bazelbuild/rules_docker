package main

import (
	"bytes"
	"compress/gzip"
	"io"
	"os"
)

var gzipMagicHeader = []byte{'\x1f', '\x8b'}

// gzReadCloser is a wrapper around gzip.Reader which closes the underlying
// reader of gzip.Reader on Close.
type gzReadCloser struct {
	// Compressed gzip.Reader
	gr io.ReadCloser
	// Underlying reader
	r io.ReadCloser
}

func isGzip(path string) (bool, error) {
	r, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer func() {
		_ = r.Close()
	}()
	magicHeader := make([]byte, 2)
	n, err := r.Read(magicHeader)
	if n < 2 && err == io.EOF {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return bytes.Equal(magicHeader, gzipMagicHeader), nil
}

func newGZReadCloser(path string) (*gzReadCloser, error) {
	r, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	gr, err := gzip.NewReader(r)
	if err != nil {
		_ = r.Close()
		return nil, err
	}
	return &gzReadCloser{gr: gr, r: r}, nil
}

func (gzr gzReadCloser) Read(p []byte) (int, error) {
	return gzr.gr.Read(p)
}

func (gzr gzReadCloser) Close() error {
	if err := gzr.r.Close(); err != nil {
		return err
	}
	return gzr.gr.Close()
}
