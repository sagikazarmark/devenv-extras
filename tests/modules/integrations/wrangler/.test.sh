#!/usr/bin/env bash
set -euo pipefail

# Both workers build with worker-build before serving; app connects to api through the dev registry.
for _ in $(seq 1 300); do
  if curl --fail --silent "$APP_URL/" | grep -q '^app: count'; then
    break
  fi
  sleep 2
done

# Each request increments the same Counter, which runs in api.
app=$(curl --fail --silent --show-error "$APP_URL/")
api=$(curl --fail --silent --show-error "$API_URL/")
echo "$app / $api"
test "${app#app: count }" -lt "${api#api: count }"

echo "wrangler fixture passed"
