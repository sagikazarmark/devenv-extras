#!/usr/bin/env bash
set -euo pipefail

status="$(curl --silent --output /dev/null --write-out '%{http_code}' "$LITELLM_PROXY_URL/v1/models")"
test "$status" = 401

curl --fail --silent --show-error \
  -H "Authorization: Bearer sk-devenv-extras-test" \
  "$LITELLM_PROXY_URL/v1/models" | grep -q '"fake"'

echo "litellm-master-key fixture passed"
