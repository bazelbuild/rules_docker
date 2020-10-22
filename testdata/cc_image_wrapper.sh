#!/usr/bin/env bash
set -euo pipefail

"$1" || { echo "FAIL!"; exit 1; }
