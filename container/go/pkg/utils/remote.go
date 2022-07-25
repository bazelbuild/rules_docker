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
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path"
	"runtime"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/v1/remote"
)

// ComputeRemoteWriteOptions returns all options to give to
// `remote.Write()` or `remote.WriteIndex()`.
func ComputeRemoteWriteOptions(ctx context.Context, userAgent string) ([]remote.Option, error) {
	options := []remote.Option{
		remote.WithContext(ctx),
		remote.WithUserAgent(userAgent),
		remote.WithAuthFromKeychain(authn.DefaultKeychain),
		remote.WithJobs(runtime.NumCPU()),
	}

	configPath := path.Join(os.Getenv("DOCKER_CONFIG"), "config.json")
	if _, err := os.Stat(configPath); err != nil {
		return options, nil
	}

	file, err := os.Open(configPath)
	if err != nil {
		return nil, fmt.Errorf("unable to open docker config: %v", err)
	}

	var dockerConfig struct {
		HTTPHeaders map[string]string `json:"HttpHeaders,omitempty"`
	}

	if err := json.NewDecoder(file).Decode(&dockerConfig); err != nil {
		return nil, fmt.Errorf("error parsing docker config: %v", err)
	}

	httpTransportOption := remote.WithTransport(&headerTransport{
		inner:       newTransport(),
		httpHeaders: dockerConfig.HTTPHeaders,
	})

	options = append(options, httpTransportOption)

	return options, nil
}

// headerTransport sets headers on outgoing requests.
type headerTransport struct {
	httpHeaders map[string]string
	inner       http.RoundTripper
}

// RoundTrip implements http.RoundTripper.
func (ht *headerTransport) RoundTrip(in *http.Request) (*http.Response, error) {
	for k, v := range ht.httpHeaders {
		// ignore "User-Agent" as it gets overwritten
		if http.CanonicalHeaderKey(k) == "User-Agent" {
			continue
		}

		in.Header.Set(k, v)
	}

	return ht.inner.RoundTrip(in)
}

func newTransport() http.RoundTripper {
	tr := http.DefaultTransport.(*http.Transport).Clone()
	// We really only expect to be talking to a couple of hosts during a push.
	// Increasing MaxIdleConnsPerHost should reduce closed connection errors.
	tr.MaxIdleConnsPerHost = tr.MaxIdleConns / 2

	return tr
}
