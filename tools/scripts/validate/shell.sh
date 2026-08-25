#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

shells=()
while IFS= read -r -d '' f; do
  shells+=("$f")
done < <(find tools/scripts bin -type f -name '*.sh' -print0 2>/dev/null | sort -z)

if [ "${#shells[@]}" -eq 0 ]; then
  echo "no shell scripts found — skipping"
  exit 0
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${shells[@]}"
else
  echo "shellcheck not installed — run 'mise install' first"
  exit 1
fi

if command -v shfmt >/dev/null 2>&1; then
  shfmt -d -i 2 -ci "${shells[@]}"
else
  echo "shfmt not installed — run 'mise install' first"
  exit 1
fi
