module KnowledgeBase
  class StyleSpecWriter
    # `name` here is A0's research focus (a sentence, possibly with price band / size detail).
    # The buyer-facing `name` is derived from the slug; the research focus is preserved under
    # `production_model.research_focus`.
    def self.create_or_update_style_level(slug:, name:, mood:, content_type:, frame_form:,
                                          production_model: nil, reference_essence: nil)
      path = Workflow::RunMode.write_root.join("style_specs", "#{slug}.yml")

      doc = path.exist? ? YAML.safe_load_file(path, permitted_classes: [Date]) : {}
      doc["slug"]      = slug
      doc["name"]      = buyer_facing_name(slug)
      doc["locked_at"] = Date.current.to_s
      doc["style_level"] = {
        "mood"         => mood.to_s,
        "content_type" => content_type.to_s,
        "frame_form"   => frame_form.to_s
      }
      doc["production_model"] =
        (doc["production_model"] || {}).merge("research_focus" => name.to_s)
                                      .merge((production_model || {}).stringify_keys)
      doc["reference_essence"] = reference_essence.deep_stringify_keys if reference_essence.present?
      doc["scenes"] ||= {}   # module 02 fills this; never clear it here

      validate_name!(doc["name"])
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

    def self.buyer_facing_name(slug)
      slug.to_s
          .sub(/-v\d+\z/i, "")
          .sub(/-\d+\z/, "")
          .tr("-", " ")
          .humanize
    end

    def self.validate_name!(name)
      errors = []
      errors << "more than 5 words" if name.to_s.split.size > 5
      errors << "contains parentheses" if name.to_s.match?(/[()]/)
      errors << "contains a price" if name.to_s.match?(/\$|\d+\s*[-–]\s*\d+/)
      if name.to_s.match?(/\b(digital|physical|print|download)\b/i)
        errors << "contains a fulfillment/format token"
      end

      return if errors.empty?

      raise IncompleteSpecError, "style name #{name.inspect} is not buyer-facing: #{errors.join('; ')}"
    end

    def self.validate_values!(style_level)
      StyleSpec::STYLE_LEVEL_AXES.each do |axis|
        value = style_level[axis.to_s]
        allowed = StyleSpec::ALLOWED[axis]
        next if allowed.include?(value.to_s)

        raise IncompleteSpecError, "style_level.#{axis}='#{value}' not in #{allowed}"
      end
    end

    def self.write_subject_research(slug, subject_research)
      write_research_block(slug, "subject_research", subject_research)
    end

    def self.write_scene_research(slug, scene_research)
      write_research_block(slug, "scene_research", scene_research)
    end

    def self.write_research_block(slug, key, value)
      path = Workflow::RunMode.write_root.join("style_specs", "#{slug}.yml")
      unless path.exist?
        raise IncompleteSpecError, "Style spec '#{slug}' not found. Run Track A A5 first."
      end

      doc = YAML.safe_load_file(path, permitted_classes: [Date])
      doc[key] = value.deep_stringify_keys
      path.write(<<~HEADER + doc.to_yaml.sub(/\A---\n/, ""))
        # Style Spec — style-level axes set by Track A (module 01),
        # scene axes appended by Track B (module 02).
        ---
      HEADER

      StyleSpec.load(slug)
    end
  end
end
