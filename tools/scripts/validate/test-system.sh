#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

CHROME_BIN=""
if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="$(command -v google-chrome)"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="$(command -v chromium)"
elif [ -d "/Applications/Google Chrome.app" ]; then
  CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
fi

if [ -z "$CHROME_BIN" ]; then
  echo "Chrome/Chromium not found — skipping system tests"
  exit 0
fi

export RAILS_ENV=test
export CHROME_BIN
bin/rails test:system
