#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

fail=0
while IFS= read -r -d '' f; do
  if ! ruby -c "$f" >/dev/null 2>&1; then
    echo "SYNTAX ERROR: $f"
    ruby -c "$f"
    fail=1
  fi
done < <(find app config db lib test tools -name '*.rb' -print0 2>/dev/null)

if [ "$fail" -ne 0 ]; then
  echo "syntax: FAIL"
  exit 1
fi
echo "syntax: all .rb files parse cleanly"
