#!/usr/bin/env bash
set -euo pipefail

curl --fail --silent --show-error "$RESTATE_ADMIN_URL/health" >/dev/null
curl --fail --silent --show-error "$RESTATE_INGRESS_URL/restate/health" >/dev/null

restate --json whoami | jq -e '.admin_health.healthy' >/dev/null

# The health endpoints respond before the node registers itself and its partitions elect leaders.
cluster_ready() {
  status="$(restatectl status)"
  partitions="$(restatectl partitions list)"
  grep -q ' test-node ' <<<"$status" && [ "$(grep -c ' Leader ' <<<"$partitions")" -eq 2 ]
}

for _ in $(seq 1 60); do
  cluster_ready && break
  sleep 0.5
done

if ! cluster_ready; then
  echo "the node should be named test-node and run 2 partitions as leader" >&2
  printf '%s\n%s\n' "$status" "$partitions" >&2
  exit 1
fi

test -d "$DEVENV_STATE/custom-restate/test-node"
test ! -e "$DEVENV_STATE/restate"

if curl --fail --silent --location "$RESTATE_ADMIN_URL/ui/" >/dev/null; then
  echo "the web UI should be disabled" >&2
  exit 1
fi

echo "restate-configured fixture passed"
