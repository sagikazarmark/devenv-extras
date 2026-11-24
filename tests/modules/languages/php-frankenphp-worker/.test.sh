#!/usr/bin/env bash
set -euo pipefail

request() {
  curl --silent --show-error --fail "$FRANKENPHP_URL/"
}

# Worker mode: the worker that booted handles the next request too.
first="$(request)"
second="$(request)"
echo "$first"
echo "$second"
jq -e '.message == "original"' <<<"$first" >/dev/null
worker="$(jq -r '.worker' <<<"$first")"
if [ "$(jq -r '.worker' <<<"$second")" != "$worker" ]; then
  echo "requests should reach the same worker" >&2
  exit 1
fi

# Watching: editing the worker script restarts the worker with the new code.
sed -i.orig "s/'original'/'changed'/" public/index.php
rm public/index.php.orig

for _ in $(seq 1 50); do
  response="$(request || true)"
  if jq -e --arg worker "$worker" '.message == "changed" and .worker != $worker' <<<"$response" >/dev/null 2>&1; then
    echo "$response"
    echo "languages php-frankenphp-worker fixture passed"
    exit 0
  fi
  sleep 0.2
done

echo "the worker did not restart after its script changed: $response" >&2
exit 1
