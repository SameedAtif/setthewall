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
    SCENE_AXES = %i[wall_condition furniture_weight room_type room_shape space_math color_role].freeze

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

    attr_reader :slug, :name, :style_level, :scenes, :path

    # The slug's human name, for listing copy. `name` is the A0 research label (which can carry a
    # price band and narrowing detail); this is the market-facing term — "whimsigoth-v1" → "Whimsigoth".
    def display_name
      slug.to_s
          .sub(/-v\d+\z/i, "")
          .sub(/-\d+\z/, "")
          .tr("-", " ")
          .humanize
    end

    def self.load(slug)
      path = Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml")
      raise IncompleteSpecError, "No style spec at #{path}" unless path.exist?

      new(YAML.safe_load_file(path, permitted_classes: [Date]), path)
    end

    def self.all
      Dir.glob(Pipeline::KB_ROOT.join("style_specs", "*.yml")).map do |f|
        load(File.basename(f, ".yml"))
      end
    end

    def initialize(raw, path)
      @path        = path
      @slug        = raw.fetch("slug")
      @name        = raw.fetch("name")
      @style_level = raw.fetch("style_level").symbolize_keys
      @scenes      = raw.fetch("scenes", {})
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

      raise IncompleteSpecError, "#{slug}: no scene templates defined" if scenes.empty?
      scene_ids.each { |id| scene(id).validate! }

      true
    end
  end
end
