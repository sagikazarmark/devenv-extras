#!/usr/bin/env bash
set -euo pipefail

command -v sandbox-agent >/dev/null
sandbox-agent --help >/dev/null
curl --fail --silent --show-error http://127.0.0.1:2468/ >/dev/null

echo "sandbox-agent fixture passed"
