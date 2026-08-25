#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

ruby -ryaml -rdate -e '
errors = []
paths = []
%w[config knowledge_base .github lefthook.yml].each do |root|
  if File.directory?(root)
    paths.concat(Dir.glob("#{root}/**/*.{yml,yaml}"))
  elsif File.exist?(root)
    paths << root
  end
end
paths.uniq.sort.each do |f|
  begin
    YAML.safe_load_file(f, permitted_classes: [Date], aliases: true)
  rescue => e
    errors << "#{f}: #{e.message}"
  end
end
if errors.any?
  puts errors.join("\n")
  exit 1
end
puts "yaml: #{paths.size} file(s) parse cleanly"
'
