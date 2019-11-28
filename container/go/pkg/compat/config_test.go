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
////////////////////////////////////////////////
// This package manipulates v2.2 image configuration metadata.
// It writes out both a config file and a manifest for the v2.2 image.

package compat

import (
	"bytes"
	"testing"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/kylelemons/godebug/pretty"
)

// TestStamper runs test case on a Stamper that has loaded the subsitutions
// from a stamp info file but hasn't been uniquified yet.
func TestStamper(t *testing.T) {
	testCases := []struct {
		name string
		// stampInfo represents the contents of a stamp file that will be
		// used to create the stamper that will stamp "value".
		stampInfo string
		// value is the value that will be stamped.
		value string
		// value is the value to expect after stamping "value".
		wantValue string
	}{
		{
			name:      "StampEmpty",
			stampInfo: "key1 value1",
			value:     "",
			wantValue: "",
		},
		{
			name:      "StampSingleSub",
			stampInfo: "key1 value1 value2",
			value:     "hello_{key1}_hello",
			wantValue: "hello_value1 value2_hello",
		},
		{
			name: "StampMultipleSub",
			stampInfo: `key1 value1
key2 value2`,
			value:     "hello_{key1}_{key2}_hello",
			wantValue: "hello_value1_value2_hello",
		},
		{
			name: "StampDuplicateSub",
			stampInfo: `key1 value1
key1 value12
key2 value2`,
			value:     "hello_{key1}_{key2}_hello",
			wantValue: "hello_value12_value2_hello",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			s := &Stamper{}
			if err := s.loadSubs(bytes.NewBufferString(tc.stampInfo)); err != nil {
				t.Fatalf("Unable to initialize stamper from stampInfo in test case: %v", err)
			}
			s.uniquify()
			got := s.Stamp(tc.value)
			if got != tc.wantValue {
				t.Errorf("Unexpected stampted value, got %q, want %q.", got, tc.wantValue)
			}
		})
	}
}

// TestConfigEnvResolution runs test cases on the updateConfig function to
// test various scenarios of resolving the image environment.
func TestConfigEnvResolution(t *testing.T) {
	testCases := []struct {
		name    string
		opts    OverrideConfigOpts
		wantEnv map[string]string
	}{
		{
			name: "EmptyEnv",
			opts: OverrideConfigOpts{
				ConfigFile: &v1.ConfigFile{},
				Env:        []string{},
			},
			wantEnv: map[string]string{},
		},
		{
			name: "UpdateEmptyEnv",
			opts: OverrideConfigOpts{
				ConfigFile: &v1.ConfigFile{},
				Env:        []string{"foo=bar"},
				Stamper:    &Stamper{},
			},
			wantEnv: map[string]string{"foo": "bar"},
		},
		{
			name: "ResolveEnv",
			opts: OverrideConfigOpts{
				ConfigFile: &v1.ConfigFile{
					Config: v1.Config{
						Env: []string{"foo=bar"},
					},
				},
				Env:     []string{"foo=$foo:baz"},
				Stamper: &Stamper{},
			},
			wantEnv: map[string]string{"foo": "bar:baz"},
		},
		{
			// Tests the case where a variable in the override information
			// uses "$" to attempt resolution but is not present in the base
			// image config. The "$var" should be left unchanged in the
			// resulting config.
			name: "ResolveUndefinedVarEnv",
			opts: OverrideConfigOpts{
				ConfigFile: &v1.ConfigFile{},
				Env:        []string{"foo=$foo:baz"},
				Stamper:    &Stamper{},
			},
			wantEnv: map[string]string{"foo": "$foo:baz"},
		},
	}
	for _, tc := range testCases {
		if err := updateConfig(&tc.opts); err != nil {
			t.Fatalf("Failed to update config: %v", err)
		}
		gotEnv, err := keyValueToMap(tc.opts.ConfigFile.Config.Env)
		if err != nil {
			t.Fatalf("Failed to convert environment in generated config to key value map: %v", err)
		}
		if diff := pretty.Compare(tc.wantEnv, gotEnv); diff != "" {
			t.Errorf("Environment in image config was not updated as expected. Want returned diff (-want +got):\n%s", diff)
		}
	}
}

// TestUserOverride ensures updateConfig doesn't override the User field in
// the base image config if the override options didn't specify a user.
func TestUserOverride(t *testing.T) {
	want := "user"
	opts := &OverrideConfigOpts{
		User: "",
		ConfigFile: &v1.ConfigFile{
			Config: v1.Config{
				User: want,
			},
		},
		Stamper: &Stamper{},
	}
	if err := updateConfig(opts); err != nil {
		t.Fatalf("Failed to update config: %v", err)
	}
	if opts.ConfigFile.Config.User != want {
		t.Errorf("User field in config was updated to invalid value, got %q, want %q.", opts.ConfigFile.Config.User, want)
	}
}

// TestWorkdirOverride ensures updateConfig doesn't override the Workdir field
// in the base image config if the override options didn't specify a working
// dir.
func TestWorkdirOverride(t *testing.T) {
	want := "workdir"
	opts := &OverrideConfigOpts{
		Workdir: "",
		ConfigFile: &v1.ConfigFile{
			Config: v1.Config{
				WorkingDir: want,
			},
		},
		Stamper: &Stamper{},
	}
	if err := updateConfig(opts); err != nil {
		t.Fatalf("Failed to update config: %v", err)
	}
	if opts.ConfigFile.Config.WorkingDir != want {
		t.Errorf("WorkingDir field in config was updated to invalid value, got %q, want %q.", opts.ConfigFile.Config.WorkingDir, want)
	}
}

func TestEntrypointPrefix(t *testing.T) {
	want := []string{"prefix1", "prefix2", "entrypoint1", "entrypoint2"}
	opts := &OverrideConfigOpts{
		EntrypointPrefix: want[:2],
		Entrypoint:       want[2:],
		ConfigFile: &v1.ConfigFile{
			Config: v1.Config{
				Entrypoint: want,
			},
		},
		Stamper: &Stamper{},
	}
	if err := updateConfig(opts); err != nil {
		t.Fatalf("Failed to update config: %v", err)
	}
	if !stringSlicesEqual(opts.ConfigFile.Config.Entrypoint, want) {
		t.Errorf("Entrypoint field in config was updated to invalid value, got %q, want %q.", opts.ConfigFile.Config.Entrypoint, want)
	}
}

func stringSlicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
