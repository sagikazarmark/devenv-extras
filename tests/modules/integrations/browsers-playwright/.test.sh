#!/usr/bin/env bash
set -euo pipefail

npm ci --no-audit --no-fund

# Headless Chromium runs chromium-headless-shell, the only browser installed.
node --input-type=module -e '
import { chromium } from "playwright-core";

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto("data:text/html,<title>browsers fixture</title>");
const title = await page.title();
console.log(browser.version(), title);
await browser.close();

if (title !== "browsers fixture") process.exit(1);
'

echo "browsers playwright fixture passed"
