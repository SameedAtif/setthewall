#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

export RAILS_ENV=test
bin/rails db:prepare
bin/rails db:abort_if_pending_migrations
echo "db: prepared; no pending migrations"
