#!/usr/bin/env bash
set -euo pipefail

dx --version | grep -q "0.7.9"
wasm-bindgen --version | grep -q "0.2.100"
esbuild --version | grep -q "0.25.5"
wasm-opt --version | grep -q "131"

echo "dioxus-cargo-lock fixture passed"
