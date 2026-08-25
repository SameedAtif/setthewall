#!/usr/bin/env bash
# Environment doctor. Reports toolchain + system deps + API-key gaps.
# Fails on missing toolchain/system deps; API-key gaps are informational
# (the pipeline runs in `manual` mode without them).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0

have() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "ok   $1"
  else
    echo "MISS $1"
    fail=1
  fi
}

echo "== toolchain =="
echo "ruby:   $(ruby -v 2>&1)"
echo "rails:  $(bin/rails -v 2>/dev/null || echo MISSING)"
echo "bundle: $(bundle -v 2>&1)"
have psql
have git
have mise

echo ""
echo "== system deps =="
if command -v vips >/dev/null 2>&1; then
  echo "ok   libvips $(vips --version 2>/dev/null)"
else
  echo "MISS libvips (brew install vips) — required by the compositor"
  fail=1
fi

echo ""
echo "== database =="
if bin/rails db:prepare >/dev/null 2>&1; then
  echo "ok   test/development DB preparable"
else
  echo "MISS database (run: bin/rails db:prepare)"
  fail=1
fi

echo ""
echo "== API keys (.env) =="
if [ ! -f .env ]; then
  echo "MISS .env — copy .env.example and fill in keys (see docs/API_KEYS.md)"
else
  while IFS='=' read -r key val; do
    case "$key" in '' | '#'*) continue ;; esac
    key="${key// /}"
    [ -z "$key" ] && continue
    if [ -z "$val" ]; then
      echo "MISS $key"
    else
      echo "ok   $key"
    fi
  done <.env
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "doctor: all toolchain/system checks green"
else
  echo "doctor: $fail toolchain/system check(s) missing"
fi
exit $fail
