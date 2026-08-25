# Knowledge-base integrity gate. Runs under `bin/rails runner`.
# Verifies every rules/*.yml carries provenance (meta.source + meta.citation),
# every prompts/*.md is non-empty, and every style_specs/*.yml validates.

errors = []

Dir[Pipeline::KB_ROOT.join("rules/*.yml")].sort.each do |f|
  name = File.basename(f, ".yml")
  begin
    r = KnowledgeBase::RuleSet.load(name)
    errors << "#{name}: missing meta.source" if r.meta["source"].blank?
    errors << "#{name}: missing meta.citation" if r.meta["citation"].blank?
  rescue => e
    errors << "#{name}: #{e.message}"
  end
end

Dir[Pipeline::KB_ROOT.join("prompts/*.md")].sort.each do |f|
  errors << "#{File.basename(f)}: empty prompt" if File.read(f).strip.empty?
end

Dir[Pipeline::KB_ROOT.join("style_specs/*.yml")].sort.each do |f|
  slug = File.basename(f, ".yml")
  begin
    KnowledgeBase::StyleSpec.load(slug).validate!
  rescue => e
    errors << "#{slug}: #{e.message}"
  end
end

if errors.any?
  puts "kb integrity: FAIL"
  puts errors.join("\n")
  exit 1
end

puts "kb integrity: all rule files cited, all prompts non-empty, all style specs valid"
