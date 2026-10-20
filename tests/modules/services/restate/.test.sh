#!/usr/bin/env bash
set -euo pipefail

curl --fail --silent --show-error "$RESTATE_ADMIN_URL/health" >/dev/null
curl --fail --silent --show-error "$RESTATE_INGRESS_URL/restate/health" >/dev/null

# The server advertises the allocated ingress port.
curl --fail --silent --show-error "$RESTATE_ADMIN_URL/version" |
  jq -e --arg url "$RESTATE_INGRESS_URL/" '.ingress_endpoint == $url' >/dev/null

restate --json whoami | jq -e '.admin_health.healthy' >/dev/null
restate deployments list --json | jq -e '.deployments == []' >/dev/null

# restatectl talks to the node port.
restatectl status | grep -q devenv
test "$(restatectl partitions list | grep -c Leader)" -eq 4

test -d "$DEVENV_STATE/restate/devenv"

echo "restate fixture passed"
