#!/usr/bin/env bash
set -euo pipefail

test -f "$DIOXUS_OUTPUT/public/index.html"
find "$DIOXUS_OUTPUT/public" -name '*.wasm' | grep -q .

# The server finds the web app in public next to it, and renders the page.
IP=127.0.0.1 PORT=18123 "$DIOXUS_OUTPUT/server" &
server=$!
trap 'kill "$server"' EXIT
wait_for_port 18123
curl --fail --silent --show-error http://127.0.0.1:18123/ | grep -q 'Hello from a Nix-built fullstack app!'

echo "dioxus fullstack import fixture passed"
