#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

echo "== brakeman =="
bin/brakeman --no-pager -q

echo "== bundler-audit =="
bundle exec bundle-audit check --update
