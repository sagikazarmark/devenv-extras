#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
pids=()
cleanup() {
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  rm -rf "$tmp"
}
trap cleanup EXIT

free_port() {
  python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'
}

# Opens a page in a WebDriver session with the given capabilities, and checks its title.
webdriver() {
  local driver="$1" capabilities="$2" port url session title

  port="$(free_port)"
  url="http://127.0.0.1:$port"
  "$driver" --port="$port" >"$tmp/$driver.log" 2>&1 &
  pids+=("$!")

  for _ in $(seq 1 50); do
    if curl --silent --fail "$url/status" | jq -e '.value.ready' >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done

  session="$(
    curl --silent --show-error --fail -X POST "$url/session" \
      -H 'Content-Type: application/json' \
      -d "{\"capabilities\": {\"alwaysMatch\": $capabilities}}" |
      jq -r '.value.sessionId'
  )"
  curl --silent --show-error --fail -X POST "$url/session/$session/url" \
    -H 'Content-Type: application/json' \
    -d '{"url": "data:text/html,<title>browsers fixture</title>"}' >/dev/null
  title="$(curl --silent --show-error --fail "$url/session/$session/title" | jq -r '.value')"
  curl --silent --fail -X DELETE "$url/session/$session" >/dev/null || true

  if [ "$title" != "browsers fixture" ]; then
    echo "$driver: unexpected title: $title" >&2
    cat "$tmp/$driver.log" >&2
    exit 1
  fi
}

# The launcher on macOS, Firefox itself on Linux.
firefox --version | grep -q 'Mozilla Firefox'

webdriver geckodriver "$(
  jq -n --arg binary "$FIREFOX_BIN" \
    '{browserName: "firefox", "moz:firefoxOptions": {binary: $binary, args: ["-headless"]}}'
)"

# CI runners do not allow the Chrome sandbox.
webdriver chromedriver "$(
  jq -n --arg binary "$CHROME_BIN" \
    '{browserName: "chrome", "goog:chromeOptions": {binary: $binary, args: ["--headless=new", "--no-sandbox"]}}'
)"

echo "browsers fixture passed"
