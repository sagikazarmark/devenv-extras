#!/usr/bin/env bash
set -euo pipefail

# The host build loads into PHP, alone and through php.withExtensions.
test "$(cat "$PHP_EXT_RS_HOST_LOAD_TEST")" = "hello-php"
test "$("$PHP_EXT_RS_PHP/bin/php" -r 'echo hello_php("devenv");')" = "Hello, devenv!"

check_target() {
  local target="$1" extension="$2"

  case "$target" in
    x86_64-unknown-linux-gnu) file -L "$extension" | grep -q "ELF 64-bit LSB shared object, x86-64" ;;
    aarch64-unknown-linux-gnu) file -L "$extension" | grep -q "ELF 64-bit LSB shared object, ARM aarch64" ;;
    aarch64-apple-darwin) file -L "$extension" | grep "Mach-O 64-bit" | grep "arm64" | grep -q "shared library" ;;
    *)
      echo "unexpected target $target" >&2
      exit 1
      ;;
  esac
}

builds=0
for extension in "$PHP_EXT_RS_MATRIX"/php-*/*/hello.so; do
  check_target "$(basename "$(dirname "$extension")")" "$extension"
  builds=$((builds + 1))
done
test "$builds" -eq 2
ls -d "$PHP_EXT_RS_MATRIX"/php-*-zts >/dev/null

check_target "$PHP_EXT_RS_CROSS_TARGET" "$PHP_EXT_RS_CROSS/lib/php/extensions/hello.so"

# The shell builds the extension with cargo against languages.php.
cargo build --release --quiet
library="$(find target/release -maxdepth 1 \( -name libhello_php.so -o -name libhello_php.dylib \))"
php -n -d display_errors=stderr -d "extension=$PWD/$library" -r 'echo hello_php("cargo");' | grep -q "Hello, cargo!"

echo "php-ext-rs import fixture passed"
