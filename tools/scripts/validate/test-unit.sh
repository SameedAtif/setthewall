#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

export RAILS_ENV=test
bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb"
