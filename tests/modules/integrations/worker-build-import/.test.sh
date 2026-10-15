#!/usr/bin/env bash
set -euo pipefail

test -f "$WORKER_BUILD_OUTPUT/index.js"
ls "$WORKER_BUILD_OUTPUT"/*.wasm

echo "worker-build import fixture passed"
