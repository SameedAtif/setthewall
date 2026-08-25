#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks not installed — run 'mise install' first"
  exit 1
fi

gitleaks detect --no-banner --redact --config=.gitleaks.toml --source=. --exit-code=1
