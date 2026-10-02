#!/usr/bin/env bash
set -euo pipefail

curl --fail --silent --show-error "$LITELLM_PROXY_URL/v1/models" | grep -q '"ollama/gemma3"'

# The model is not pulled, so Ollama itself should reject the request.
response="$(curl --silent --show-error "$LITELLM_PROXY_URL/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model": "ollama/missing-model", "messages": [{"role": "user", "content": "hi"}]}')"
grep -q 'not found' <<<"$response"

echo "litellm-ollama fixture passed"
