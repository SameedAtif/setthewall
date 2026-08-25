module KnowledgeBase
  class SceneSpec
    attr_reader :id, :name, :axes, :template_ref, :style_spec

    def initialize(id, raw, style_spec)
      @id           = id.to_s
      @style_spec   = style_spec
      @name         = raw.fetch("name", id.to_s)
      @template_ref = raw["template_ref"]
      @axes         = raw.fetch("axes", {}).symbolize_keys
    end

    StyleSpec::SCENE_AXES.each do |axis|
      define_method(axis) { axes[axis] }
    end

    def validate!
      StyleSpec::SCENE_AXES.each do |axis|
        value = axes[axis]
        if value.blank?
          raise IncompleteSpecError, "#{style_spec.slug}/#{id}: axes.#{axis} is blank"
        end
        unless StyleSpec::ALLOWED[axis].include?(value.to_s)
          raise IncompleteSpecError,
                "#{style_spec.slug}/#{id}: axes.#{axis}='#{value}' not in #{StyleSpec::ALLOWED[axis]}"
        end
      end
      true
    end
  end
end
