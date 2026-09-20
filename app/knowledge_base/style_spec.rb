# The nine axes and what each controls.
#
# Style-level (3 axes, set once per style):
#   mood          calm_ordered | bold_active
#   content_type  detailed_representational | minimalist_modern | portrait_still_life
#   frame_form    angular | rounded
#
# Per-scene (6 axes, set once per scene template):
#   wall_condition    neutral | busy
#   furniture_weight  light | dark
#   room_type         seated_room | hallway | no_furniture_wall
#   room_shape        narrow | low_ceilinged | small_closed_in | none
#   space_math        single | set | split_wall | nook | surface
#   color_role        accent_highlighter | color_burst | unifier | saturator | line_only
module KnowledgeBase
  class StyleSpec
    STYLE_LEVEL_AXES = %i[mood content_type frame_form].freeze
    # color_role is NOT a scene axis — it is a style-level observation derived at A1b (see
    # docs/color-role-and-scene-decoupling-plan.md).
    SCENE_AXES = %i[wall_condition furniture_weight room_type room_shape space_math].freeze

    ALLOWED = {
      mood:             %w[calm_ordered bold_active],
      content_type:     %w[detailed_representational minimalist_modern portrait_still_life],
      frame_form:       %w[angular rounded],
      wall_condition:   %w[neutral busy],
      furniture_weight: %w[light dark],
      room_type:        %w[seated_room hallway no_furniture_wall],
      room_shape:       %w[narrow low_ceilinged small_closed_in none],
      space_math:       %w[single set split_wall nook surface],
      color_role:       %w[accent_highlighter color_burst unifier saturator line_only]
    }.freeze

    attr_reader :slug, :name, :style_level, :scenes, :path, :production_model,
                :subject_research, :scene_research, :reference_essence

    # The buyer-facing name, for listing copy. `name` is validated at lock time (A5) to be a
    # short, keyword-usable phrase; A0's full research sentence lives in production_model.
    def display_name = name.to_s

    def self.load(slug)
      path = Workflow::RunMode.write_root.join("style_specs", "#{slug}.yml")
      raise IncompleteSpecError, "No style spec at #{path}" unless path.exist?

      new(YAML.safe_load_file(path, permitted_classes: [Date]), path)
    end

    def self.all
      Dir.glob(Workflow::RunMode.write_root.join("style_specs", "*.yml")).map do |f|
        load(File.basename(f, ".yml"))
      end
    end

    def initialize(raw, path)
      @path             = path
      @slug             = raw.fetch("slug")
      @name             = raw.fetch("name")
      @style_level      = raw.fetch("style_level").symbolize_keys
      @scenes           = raw.fetch("scenes", {})
      @production_model = (raw["production_model"] || {}).stringify_keys
      @subject_research = (raw["subject_research"] || {}).stringify_keys
      @scene_research   = (raw["scene_research"] || {}).stringify_keys
      @reference_essence = (raw["reference_essence"] || {}).stringify_keys
    end

    def scene(scene_id)
      raw = scenes.fetch(scene_id.to_s) do
        raise IncompleteSpecError, "Scene '#{scene_id}' not found in #{slug}"
      end
      SceneSpec.new(scene_id, raw, self)
    end

    def scene_ids = scenes.keys

    # Raises unless every axis is present AND holds an allowed value.
    def validate!
      STYLE_LEVEL_AXES.each do |axis|
        value = style_level[axis]
        raise IncompleteSpecError, "#{slug}: style_level.#{axis} is blank" if value.blank?
        unless ALLOWED[axis].include?(value.to_s)
          raise IncompleteSpecError, "#{slug}: style_level.#{axis}='#{value}' not in #{ALLOWED[axis]}"
        end
      end

      validate_production_model!
      raise IncompleteSpecError, "#{slug}: no scene templates defined" if scenes.empty?
      scene_ids.each { |id| scene(id).validate! }

      true
    end

    def validate_production_model!
      ft = production_model["fulfillment_type"]
      pc = production_model["piece_count"]
      raise IncompleteSpecError, "#{slug}: production_model.fulfillment_type is blank" if ft.blank?
      unless %w[digital physical].include?(ft.to_s)
        raise IncompleteSpecError, "#{slug}: production_model.fulfillment_type='#{ft}' not in [digital, physical]"
      end
      raise IncompleteSpecError, "#{slug}: production_model.piece_count is blank" if pc.blank?
      raise IncompleteSpecError, "#{slug}: production_model.piece_count='#{pc}' must be >= 1" if pc.to_i < 1
    end
  end
end
