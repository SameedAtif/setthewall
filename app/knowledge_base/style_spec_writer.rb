module KnowledgeBase
  class StyleSpecWriter
    def self.create_or_update_style_level(slug:, name:, mood:, content_type:, frame_form:)
      path = Workflow::RunMode.write_root.join("style_specs", "#{slug}.yml")

      doc = path.exist? ? YAML.safe_load_file(path, permitted_classes: [Date]) : {}
      doc["slug"]      = slug
      doc["name"]      = name
      doc["locked_at"] = Date.current.to_s
      doc["style_level"] = {
        "mood"         => mood.to_s,
        "content_type" => content_type.to_s,
        "frame_form"   => frame_form.to_s
      }
      doc["scenes"] ||= {}   # module 02 fills this; never clear it here

      validate_values!(doc["style_level"])

      path.dirname.mkpath
      path.write(<<~HEADER + doc.to_yaml.sub(/\A---\n/, ""))
        # Style Spec — style-level axes set by Phase 1 Track A.
        # Scene axes are appended by Track B (module 02). Do not hand-edit scene keys here
        # without also re-running Track B's validation.
        ---
      HEADER

      StyleSpec.load(slug)
    end

    def self.validate_values!(style_level)
      StyleSpec::STYLE_LEVEL_AXES.each do |axis|
        value = style_level[axis.to_s]
        allowed = StyleSpec::ALLOWED[axis]
        next if allowed.include?(value.to_s)

        raise IncompleteSpecError, "style_level.#{axis}='#{value}' not in #{allowed}"
      end
    end
  end
end
