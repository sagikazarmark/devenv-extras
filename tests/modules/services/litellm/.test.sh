#!/usr/bin/env bash
set -euo pipefail

command -v litellm >/dev/null
curl --fail --silent --show-error "$LITELLM_PROXY_URL/health/liveliness" >/dev/null
curl --fail --silent --show-error "$LITELLM_PROXY_API_BASE/v1/models" | grep -q '"fake"'
test -d "$DEVENV_STATE/litellm/ui"

echo "litellm fixture passed"
