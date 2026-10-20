#!/usr/bin/env bash
set -euo pipefail

curl --fail --silent --show-error "$RESTATE_ADMIN_URL/health" >/dev/null
curl --fail --silent --show-error "$RESTATE_INGRESS_URL/restate/health" >/dev/null

restate --json whoami | jq -e '.admin_health.healthy' >/dev/null

restatectl status | grep -q test-node
test "$(restatectl partitions list | grep -c Leader)" -eq 2

test -d "$DEVENV_STATE/custom-restate/test-node"
test ! -e "$DEVENV_STATE/restate"

if curl --fail --silent --location "$RESTATE_ADMIN_URL/ui/" >/dev/null; then
  echo "the web UI should be disabled" >&2
  exit 1
fi

echo "restate-configured fixture passed"
