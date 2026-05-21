#!/usr/bin/env bash
set -euo pipefail

attr="$1"
output="$(devenv build "$attr")"
path="$(printf '%s\n' "$output" | jq -R -s -r --arg attr "$attr" 'try (capture("(?s).*?(?<json>\\{.*\\})\\s*$").json | fromjson | select(type == "object" and has($attr)) | .[$attr]) catch empty')"

if [ -n "$path" ]; then
  printf '%s\n' "$path"
else
  printf '%s\n' "$output"
fi
