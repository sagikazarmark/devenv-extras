#!/usr/bin/env bash
set -euo pipefail

# The postinstall script only downloads browsers.
npm ci --no-audit --no-fund --ignore-scripts

# Puppeteer reads the browser and its executable from the environment.
node --input-type=module -e '
import puppeteer from "puppeteer";

const browser = await puppeteer.launch();
const page = await browser.newPage();
await page.goto("data:text/html,<title>browsers fixture</title>");
const title = await page.title();
console.log(await browser.version(), title);
await browser.close();

if (title !== "browsers fixture") process.exit(1);
'

echo "browsers puppeteer fixture passed"
