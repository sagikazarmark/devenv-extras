#!/usr/bin/env bash
set -euo pipefail

wasm="$DIOXUS_SERVE_URL/wasm/hello-dioxus_bg.wasm"

# dx serve answers every path with a placeholder page while it builds; wait for the app's WebAssembly.
for _ in $(seq 1 300); do
  if [ "$(curl --silent --output /dev/null --write-out '%{content_type}' "$wasm")" = "application/wasm" ]; then
    curl --fail --silent --show-error "$DIOXUS_SERVE_URL/" | grep -q '/wasm/hello-dioxus.js'
    echo "dioxus serve fixture passed"
    exit 0
  fi
  sleep 2
done

echo "dx serve did not serve the app" >&2
exit 1
