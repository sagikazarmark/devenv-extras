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
# The health endpoints respond before the node registers itself and its partitions elect leaders.
cluster_ready() {
  status="$(restatectl status)"
  partitions="$(restatectl partitions list)"
  grep -q ' devenv ' <<<"$status" && [ "$(grep -c ' Leader ' <<<"$partitions")" -eq 4 ]
}

for _ in $(seq 1 60); do
  cluster_ready && break
  sleep 0.5
done

if ! cluster_ready; then
  echo "the node should run 4 partitions as leader" >&2
  printf '%s\n%s\n' "$status" "$partitions" >&2
  exit 1
fi

test -d "$DEVENV_STATE/restate/devenv"

echo "restate fixture passed"
