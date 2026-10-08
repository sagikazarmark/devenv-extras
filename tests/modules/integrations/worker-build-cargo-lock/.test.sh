#!/usr/bin/env bash
set -euo pipefail

worker-build --version | grep -q "0.8.7"

echo "worker-build-cargo-lock fixture passed"
