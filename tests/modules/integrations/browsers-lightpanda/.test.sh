#!/usr/bin/env bash
set -euo pipefail

lightpanda version
test "$LIGHTPANDA_DISABLE_TELEMETRY" = true

# fetch runs the page's JavaScript before dumping it.
lightpanda fetch --dump html "$SITE_URL" | grep -q 'Hello from JavaScript'

# CDP: Puppeteer reads the WebSocket URL from /json/version.
npm ci --no-audit --no-fund
node --input-type=module -e '
import puppeteer from "puppeteer-core";

const browser = await puppeteer.connect({ browserURL: process.env.LIGHTPANDA_URL });
const context = await browser.createBrowserContext();
const page = await context.newPage();
await page.goto(process.env.SITE_URL);
const title = await page.title();
const greeting = await page.$eval("#greeting", (element) => element.textContent);
console.log(title, greeting);
await page.close();
await context.close();
await browser.disconnect();

if (title !== "lightpanda fixture" || greeting !== "Hello from JavaScript") process.exit(1);
'

# WebDriver: the classic session endpoints on the same port.
curl --silent --show-error --fail "$LIGHTPANDA_URL/status" | jq -e '.value.ready' >/dev/null
response="$(
  curl --silent --show-error -X POST "$LIGHTPANDA_URL/session" \
    -H 'Content-Type: application/json' \
    -d '{"capabilities": {}}'
)"
session="$(jq -r '.value.sessionId // empty' <<<"$response")"
if [ -z "$session" ]; then
  echo "cannot create a WebDriver session: $response" >&2
  exit 1
fi

curl --silent --show-error --fail -X POST "$LIGHTPANDA_URL/session/$session/url" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg url "$SITE_URL" '{url: $url}')" >/dev/null
title="$(curl --silent --show-error --fail "$LIGHTPANDA_URL/session/$session/title" | jq -r '.value')"
curl --silent --fail -X DELETE "$LIGHTPANDA_URL/session/$session" >/dev/null || true

if [ "$title" != "lightpanda fixture" ]; then
  echo "unexpected WebDriver title: $title" >&2
  exit 1
fi

echo "browsers lightpanda fixture passed"
