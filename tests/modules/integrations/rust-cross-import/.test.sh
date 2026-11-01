#!/usr/bin/env bash
set -euo pipefail

"$RUST_CROSS_HOST/bin/hello-cross" | grep -q "hello from a greeting build"

file -L "$RUST_CROSS_X86_64_LINUX_MUSL/bin/hello-cross" | grep -q "ELF 64-bit.*x86-64.*statically linked"

file -L "$RUST_CROSS_AARCH64_LINUX_GNU/bin/hello-cross" | grep -q "ELF 64-bit.*ARM aarch64"
file -L "$RUST_CROSS_AARCH64_LINUX_GNU/lib/libhello_cross.so" | grep -q "ELF 64-bit.*ARM aarch64"

# Built with --lib: a cdylib links for macOS, and the binary is not built.
file -L "$RUST_CROSS_X86_64_DARWIN/lib/libhello_cross.dylib" | grep -q "Mach-O 64-bit.*x86_64"
test ! -e "$RUST_CROSS_X86_64_DARWIN/bin"

echo "rust-cross import fixture passed"
