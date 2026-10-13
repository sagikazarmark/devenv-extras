#!/usr/bin/env bash
set -euo pipefail

bao status >/dev/null
bao token lookup -format=json | grep -q '"root"'

bao kv put secret/devenv-test foo=bar >/dev/null
test "$(bao kv get -field=foo secret/devenv-test)" = bar

curl --fail --silent --show-error --location "$BAO_ADDR/ui/" >/dev/null

test -f "$DEVENV_STATE/openbao/unseal.key"
test "$(wc -c < "$DEVENV_STATE/openbao/unseal.key")" -eq 32
test -n "$(ls -A "$DEVENV_STATE/openbao/pebbledb")"
test -f "$DEVENV_STATE/openbao/pebbledb.init.sha256"

echo "openbao fixture passed"
