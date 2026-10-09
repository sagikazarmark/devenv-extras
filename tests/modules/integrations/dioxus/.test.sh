#!/usr/bin/env bash
set -euo pipefail

dx --version
wasm-bindgen --version
esbuild --version
wasm-opt --version

echo "dioxus fixture passed"
