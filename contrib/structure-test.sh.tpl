#!/usr/bin/env bash

set -ex

%{load_statement}

%{test_executable} -test.v -driver %{driver} -image %{image} %{configs}
