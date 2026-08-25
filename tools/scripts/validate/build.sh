#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

SECRET_KEY_BASE=dummy RAILS_ENV=production bin/rails assets:precompile
echo "build: assets precompiled cleanly"
