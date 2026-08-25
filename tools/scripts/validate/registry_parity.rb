# Step-registry parity gate. Runs under `bin/rails runner`.
# Verifies the canonical 38-step registry is internally consistent with the step
# classes that implement it: every registry entry resolves to a class whose
# `step_id` + `ownership` match verbatim, and no step class is left out.

raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
all = [
  *(raw.dig("phase_1", "track_a", "steps") || []),
  *(raw.dig("phase_1", "track_b", "steps") || []),
  *(raw.dig("phase_1", "track_c", "steps") || []),
  *(raw.dig("phase_2", "steps") || []),
  *(raw.dig("phase_3_module_1", "steps") || [])
]

errors = []

seen_ids = all.map { |s| s["id"] }
dupes = seen_ids.tally.select { |_, c| c > 1 }.keys
errors << "duplicate step ids: #{dupes.join(', ')}" if dupes.any?

all.each do |s|
  klass = s["klass"].safe_constantize
  unless klass
    errors << "#{s['id']}: class #{s['klass']} does not resolve"
    next
  end
  errors << "#{s['id']}: step_id mismatch (class says #{klass.step_id.inspect})" unless klass.step_id == s["id"]
  errors << "#{s['id']}: ownership mismatch" unless klass.ownership == s["ownership"]
end

# Reverse direction: any class declaring a step_id must appear in the registry.
implemented_ids = Dir[Rails.root.join("app/steps/**/*.rb")].filter_map do |f|
  src = File.read(f)
  src[/\bstep\s+id:\s*"([^"]+)"/, 1]
end
unregistered = implemented_ids - seen_ids
errors << "step classes not in registry: #{unregistered.join(', ')}" if unregistered.any?

if errors.any?
  puts "registry parity: FAIL"
  puts errors.join("\n")
  exit 1
end

puts "registry parity: #{all.size} steps all resolve + match, no orphan step classes"
