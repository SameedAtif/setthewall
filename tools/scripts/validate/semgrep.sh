#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if ! command -v semgrep >/dev/null 2>&1; then
  echo "semgrep not installed — skipping (install with: pipx install semgrep)"
  exit 0
fi

semgrep --config auto --error .
