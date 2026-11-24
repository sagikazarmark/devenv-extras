#!/usr/bin/env bash
set -euo pipefail

frankenphp version

# FrankenPHP embeds the PHP of languages.php, with its extensions and ini directives.
cli="$(frankenphp php-cli public/index.php)"
echo "$cli"
jq -e '.zts and .shmop and .memory_limit == "345M"' <<<"$cli" >/dev/null

# The server also reads languages.php.frankenphp.serve.ini.
response="$(curl --silent --show-error --fail "$FRANKENPHP_URL/")"
echo "$response"
jq -e '.sapi == "frankenphp" and .zts and .shmop and .memory_limit == "456M"' <<<"$response" >/dev/null

echo "languages php-frankenphp fixture passed"
