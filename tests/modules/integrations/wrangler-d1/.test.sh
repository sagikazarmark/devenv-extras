#!/usr/bin/env bash
set -euo pipefail

for _ in $(seq 1 60); do
  if curl --fail --silent "$WRITER_URL/" >/dev/null && curl --fail --silent "$READER_URL/" >/dev/null; then
    break
  fi
  sleep 1
done

# The migrations ran in the dev environment, before the workers started.
writer=$(curl --fail --silent --show-error "$WRITER_URL/")
reader=$(curl --fail --silent --show-error "$READER_URL/")
echo "$writer / $reader"

test "$(jq -r .greeting <<<"$writer")" = "hello from dev"
test "$(jq -r .self <<<"$writer")" = "$WRITER_URL"
test "$(jq -r .count <<<"$writer")" = 2

# The reader shares the writer's directory, and with it the database.
test "$(jq -r .count <<<"$reader")" = 2

echo "wrangler-d1 fixture passed"
