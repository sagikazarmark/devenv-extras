#!/usr/bin/env bash
set -euo pipefail

command -v tailwindcss >/dev/null

if command -v tailwindcss-language-server >/dev/null; then
  echo "tailwindcss-language-server should not be installed" >&2
  exit 1
fi

echo "tailwindcss-lsp-disabled fixture passed"
