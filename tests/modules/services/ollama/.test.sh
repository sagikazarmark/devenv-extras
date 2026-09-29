#!/usr/bin/env bash
set -euo pipefail

command -v ollama >/dev/null
ollama --version >/dev/null
curl --fail --silent --show-error "http://$OLLAMA_HOST/api/version" >/dev/null
curl --fail --silent --show-error "$OLLAMA_BASE_URL/models" >/dev/null
ollama list >/dev/null
test -d "$DEVENV_STATE/ollama/models"

echo "ollama fixture passed"
