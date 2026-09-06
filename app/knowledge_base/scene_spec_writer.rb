module KnowledgeBase
  class SceneSpecWriter
    # Overwrites the axes for one scene under an existing style spec.
    # Refuses to run if style_level hasn't been locked yet (A5 must complete first).
    def self.write_scene_axes(style_slug:, scene_id:, scene_name:, template_ref:, axes:)
      path = Workflow::RunMode.write_root.join("style_specs", "#{style_slug}.yml")
      unless path.exist?
        raise IncompleteSpecError,
              "Style spec '#{style_slug}' not found. Run Track A (module 01) first."
      end

      doc = YAML.safe_load_file(path, permitted_classes: [Date])
      if doc["style_level"].blank?
        raise IncompleteSpecError,
              "Style spec '#{style_slug}' has no style_level. Track A A5 must run before Track B."
      end

      validate_axes!(axes)

      doc["scenes"] ||= {}
      doc["scenes"][scene_id.to_s] = {
        "name"         => scene_name,
        "template_ref" => template_ref,
        "locked_at"    => Date.current.to_s,
        "axes"         => axes.transform_keys(&:to_s).transform_values(&:to_s)
      }

      path.write(<<~HEADER + doc.to_yaml.sub(/\A---\n/, ""))
        # Style Spec — style-level axes set by Track A (module 01),
        # scene axes appended by Track B (module 02).
        ---
      HEADER

      StyleSpec.load(style_slug).scene(scene_id.to_s)
    end

    def self.validate_axes!(axes)
      StyleSpec::SCENE_AXES.each do |axis|
        value = axes[axis] || axes[axis.to_s]
        allowed = StyleSpec::ALLOWED[axis]
        if value.blank?
          raise IncompleteSpecError, "axes.#{axis} is blank — every scene axis must have a value"
        end
        unless allowed.include?(value.to_s)
          raise IncompleteSpecError, "axes.#{axis}='#{value}' not in #{allowed}"
        end
      end
    end
  end
end
