#!/usr/bin/env bash
set -euo pipefail

cargo-zigbuild --version

cargo zigbuild --release --target aarch64-unknown-linux-musl
file target/aarch64-unknown-linux-musl/release/hello-shell | grep -q "ELF 64-bit.*ARM aarch64.*statically linked"

echo "rust-cross fixture passed"
