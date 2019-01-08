#!/usr/bin/env bash

set -ex

%{load_statement}

%{test_executable} version

%{test_executable} %{args}
