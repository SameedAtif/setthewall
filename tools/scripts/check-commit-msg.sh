#!/usr/bin/env bash
# Conventional-commit guard for the commit-msg hook. $1 is the message file.
set -euo pipefail

msg_file="${1:-}"
if [ -z "$msg_file" ] || [ ! -f "$msg_file" ]; then
  echo "commit-msg: no message file provided" >&2
  exit 1
fi

msg="$(cat "$msg_file")"

# Skip merge/revert commits, which don't follow the convention.
if grep -qE '^(Merge|Revert|Squashed)' <<<"$msg"; then
  exit 0
fi

if ! grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z-]+\))?!?: ' <<<"$msg"; then
  echo "commit-msg: subject must follow Conventional Commits:" >&2
  echo "  type(scope): subject   e.g. \"feat(pipeline): add Etsy listing step\"" >&2
  exit 1
fi
