#!/usr/bin/env bash
set -euo pipefail

# Tailwind colors its output when CI is set, which splits "tailwindcss v4" with escape codes.
NO_COLOR=1 tailwindcss --help | grep -q "tailwindcss v4"
command -v tailwindcss-language-server >/dev/null

echo "tailwindcss fixture passed"
