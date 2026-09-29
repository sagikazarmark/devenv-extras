#!/usr/bin/env bash
set -euo pipefail

curl --fail --silent --show-error "http://$OLLAMA_HOST/api/version" >/dev/null
curl --fail --silent --show-error "$OLLAMA_BASE_URL/models" >/dev/null
ollama list >/dev/null
test -d "$DEVENV_STATE/custom-models"

echo "ollama-configured fixture passed"
