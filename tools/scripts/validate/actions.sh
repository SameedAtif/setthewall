#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if [ ! -d .github/workflows ]; then
  echo "no .github/workflows — skipping"
  exit 0
fi

if ! command -v actionlint >/dev/null 2>&1; then
  echo "actionlint not installed — run 'mise install' first"
  exit 1
fi

actionlint
