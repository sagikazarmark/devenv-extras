#!/usr/bin/env bash
set -euo pipefail

response="$(curl --silent --show-error --fail "$FRANKENPHP_URL/")"
echo "$response"
jq -e '.sapi == "frankenphp"' <<<"$response" >/dev/null

# The site matches any host, such as the hostname of devenv's proxy.
response="$(curl --silent --show-error --fail -H 'Host: frankenphp.fixture.localhost' "$FRANKENPHP_URL/")"
jq -e '.host == "frankenphp.fixture.localhost"' <<<"$response" >/dev/null

# Caddy's admin API listens on a socket in the runtime directory.
curl --silent --show-error --fail --unix-socket "$DEVENV_RUNTIME/frankenphp-admin.sock" \
  http://localhost/config/ | jq -e '.apps.http' >/dev/null

# devenv restarts the server when the Caddyfile changes.
sed -i.orig 's|^\troot {$SERVER_ROOT:public/}$|&\n\theader X-Fixture reloaded|' Caddyfile
rm Caddyfile.orig
grep -q 'X-Fixture' Caddyfile

for _ in $(seq 1 100); do
  if curl --silent --head "$FRANKENPHP_URL/" | grep -qi '^x-fixture: reloaded'; then
    echo "languages php-frankenphp-caddyfile fixture passed"
    exit 0
  fi
  sleep 0.2
done

echo "the server did not restart with the changed Caddyfile" >&2
exit 1
