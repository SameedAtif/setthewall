module Compositor
  Result = Struct.new(:output_path, :measurements, keyword_init: true)

  class Runner
    def self.call(piece:) = new(piece: piece).call

    def initialize(piece:)
      @piece = piece
      @scene = piece.style_spec.scene(piece.scene_spec_id)
      @template = load_template
    end

    def call
      art = load_art_image
      art_dims = compute_art_dimensions

      x, y = compute_position(art_dims)

      composited = paste_art_on_template(art, x: x, y: y, w: art_dims[:w], h: art_dims[:h])
      output_path = write_output(composited)

      Result.new(
        output_path: output_path,
        measurements: measurements_summary(art_dims, x, y)
      )
    end

    private

    def load_template
      path = Pipeline::KB_ROOT.join("scene_templates", "#{@piece.scene_spec_id}.yml")
      raise TemplateError, "No scene template at #{path}" unless path.exist?

      raw = YAML.safe_load_file(path, permitted_classes: [Date])
      required = %w[image_path measurements]
      missing  = required - raw.keys
      raise TemplateError, "Template missing: #{missing.join(', ')}" if missing.any?
      raw
    end

    def load_art_image
      # Loads @piece.chosen_url via Vips. If chosen_url is a remote URL, download first.
      # In practice the manual/replicate adapters will have written the file locally already.
      Vips::Image.new_from_file(local_path_for(@piece.chosen_url))
    end

    def local_path_for(url)
      # If it's already a local path, return it.
      return url if File.exist?(url.to_s)

      # Download via Faraday to tmp
      dst = Rails.root.join("tmp", "art_downloads", "#{@piece.id}_#{File.basename(URI.parse(url).path)}")
      dst.dirname.mkpath
      unless dst.exist?
        response = Faraday.get(url)
        dst.write(response.body)
      end
      dst.to_s
    end

    def compute_art_dimensions
      m   = @template.fetch("measurements")
      ppi = m.fetch("pixels_per_inch").to_i

      # === Group width vs. furniture rule (§2.11) ===
      # Group no wider than furniture; if narrower, at least half.
      furn_w = m["furniture_width_px"]

      target_w = if furn_w.present?
                   # 2/3 to 3/4 of furniture width is the "single-piece fills" rule (§2.5)
                   (furn_w * 0.7).to_i
      else
                   # No furniture (hallway/split-wall/etc.) — use wall_zone width
                   (m.dig("wall_zone", "width").to_i * 0.5)
      end

      # Naïvely square unless the source art has a known aspect ratio; leave the art's own
      # aspect ratio in place by scaling proportionally.
      art_native = Vips::Image.new_from_file(local_path_for(@piece.chosen_url))
      ratio = art_native.height.to_f / art_native.width
      target_h = (target_w * ratio).to_i

      { w: target_w.to_i, h: target_h }
    end

    def compute_position(art_dims)
      m = @template.fetch("measurements")

      # === Horizontal centering across wall zone / furniture ===
      wall_zone = m["wall_zone"] || {}
      wall_center_x = wall_zone["x"].to_i + (wall_zone["width"].to_i / 2)
      x = wall_center_x - (art_dims[:w] / 2)

      # === Vertical position — eye-level rule (§2.10) + general drop (P2-P14) ===
      ppi = m["pixels_per_inch"].to_i
      eye_rules = KnowledgeBase::RuleSet.load("eye_level").rules

      by_room = eye_rules["by_room_type"].fetch(@piece.room_type)
      anchor_key = by_room["anchor"]
      anchor_y = m.fetch(anchor_key) do
        raise TemplateError, "Template is missing measurement '#{anchor_key}' for " \
                             "room_type=#{@piece.room_type}."
      end

      center_y = if @piece.room_type == "seated_room"
                   # "Center 5-6" above the back of the couch/chairs" — but the anchor is the TOP
                   # of the furniture, so the piece CENTER sits ABOVE that anchor by 5.5" + half
                   # the piece height.
                   inches_above = by_room["formula_inches"].to_f
                   furniture_top_y = anchor_y.to_i
                   furniture_top_y - (inches_above * ppi).to_i - (art_dims[:h] / 2)
      else
                   anchor_y.to_i
      end

      # Apply the general drop rule (P2-P14): drop 3-4" — "most people hang too high"
      drop_px = (eye_rules["general_drop"]["formula_inches"].to_f.abs * ppi).to_i
      center_y += drop_px

      y = center_y - (art_dims[:h] / 2)

      # === Furniture 8-10" gap check (§2.11) — validate, don't silently fix ===
      if @piece.room_type == "seated_room"
        gap_px = anchor_y.to_i - (y + art_dims[:h])
        gap_inches = gap_px.to_f / ppi
        if gap_inches < 8 || gap_inches > 10
          # Adjust to the midpoint of the range (9")
          target_gap_px = (9.0 * ppi).to_i
          y = anchor_y.to_i - target_gap_px - art_dims[:h]
        end
      end

      [x, y]
    end

    def paste_art_on_template(art, x:, y:, w:, h:)
      template_img = Vips::Image.new_from_file(Pipeline::KB_ROOT.join(@template["image_path"]).to_s)
      resized_art  = art.resize(w.to_f / art.width)
      template_img.composite2(resized_art, :over, x: x, y: y)
    end

    def write_output(img)
      dst = Rails.root.join("tmp", "composites", "#{@piece.id}_#{Time.current.to_i}.png")
      dst.dirname.mkpath
      img.write_to_file(dst.to_s)
      dst.to_s
    end

    def measurements_summary(art_dims, x, y)
      m = @template["measurements"]
      wall_area = m["wall_zone"]["width"].to_i * m["wall_zone"]["height"].to_i
      art_area  = art_dims[:w] * art_dims[:h]
      {
        art_width_px:  art_dims[:w],
        art_height_px: art_dims[:h],
        x_px: x, y_px: y,
        pixels_per_inch: m["pixels_per_inch"],
        coverage_fraction: (art_area.to_f / wall_area).round(4),
        eye_level_anchor: m[KnowledgeBase::RuleSet.load("eye_level").rules["by_room_type"][@piece.room_type]["anchor"]]
      }
    end
  end
end
