#!/bin/bash

set -ex

%{load_statement}

%{test_executable} -test.v -image %{image} %{configs}
