#!/usr/bin/env bash
set -euo pipefail

test -f "$DIOXUS_OUTPUT/public/index.html"
find "$DIOXUS_OUTPUT/public" -name '*.wasm' | grep -q .
# The stylesheet that Tailwind CSS generated for the app.
grep -rlq 'text-red-500' "$DIOXUS_OUTPUT/public/assets" --include '*.css'

echo "dioxus import fixture passed"
