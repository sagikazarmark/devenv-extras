#!/usr/bin/env bash
set -euo pipefail

curl --fail --silent --show-error "http://$OLLAMA_HOST/api/version" >/dev/null
ollama list >/dev/null
test -d "$DEVENV_STATE/custom-models"

echo "ollama-configured fixture passed"
