#!/usr/bin/env bash
set -euo pipefail

bao token lookup -format=json | grep -q '"devenv-test"'

test -d "$DEVENV_STATE/openbao/raft/raft"

bao secrets list | grep -q '^kv/'
if bao secrets list | grep -q '^secret/'; then
  echo "the default KV mount should use the configured path" >&2
  exit 1
fi

bao auth list | grep -q '^userpass/'
bao login -no-store -method=userpass username=alice password=hunter2 >/dev/null

if curl --fail --silent --location "$BAO_ADDR/ui/" >/dev/null; then
  echo "the UI should be disabled" >&2
  exit 1
fi

echo "openbao-configured fixture passed"
