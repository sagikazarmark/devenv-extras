#!/usr/bin/env bash
set -euo pipefail

curl --silent --show-error --fail --globoff "$LIGHTPANDA_URL/status" | grep -q '"ready":true'

echo "browsers lightpanda ipv6 fixture passed"
