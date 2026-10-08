#!/usr/bin/env bash
set -euo pipefail

tailwindcss --help | grep -q "tailwindcss v4"
command -v tailwindcss-language-server >/dev/null

echo "tailwindcss fixture passed"
