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
      art = Compositor::Frame.apply(art: load_art_image, piece: @piece)
      art_dims = compute_art_dimensions(art)

      pos = compute_position(art_dims)
      x, y = clamp_to_bounds(art_dims, pos[:x], pos[:y])

      composited = paste_art_on_template(art, x: x, y: y, w: art_dims[:w], h: art_dims[:h])
      output_path = write_output(composited)

      Result.new(
        output_path: output_path,
        measurements: measurements_summary(art_dims, x, y, pos)
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
      validate_image_dimensions!(raw)
      raw
    end

    def validate_image_dimensions!(raw)
      m = raw["measurements"] || {}
      declared_w = m["image_width_px"].to_i
      declared_h = m["image_height_px"].to_i
      return if declared_w <= 0 || declared_h <= 0

      image_path = Pipeline::KB_ROOT.join(raw["image_path"]).to_s
      return unless File.exist?(image_path)

      img = Vips::Image.new_from_file(image_path)
      return if img.width == declared_w && img.height == declared_h

      raise TemplateError,
            "Template '#{@piece.scene_spec_id}' declares #{declared_w}x#{declared_h} " \
            "but the image is #{img.width}x#{img.height}"
    rescue Vips::Error
      nil
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

    def compute_art_dimensions(art_native)
      m      = @template.fetch("measurements")
      pixels_per_inch # validates ppi / calibration

      zone   = m["wall_zone"] || {}
      furn_w = m["furniture_width_px"]

      # Preferred width: 2/3–3/4 of the furniture width (§2.5), or half the wall zone otherwise.
      preferred_w = if furn_w.present?
                      (furn_w * 0.7).to_i
      else
                      (zone["width"].to_i * 0.5).to_i
      end
      # The usable band (ceiling clearance at the top, furniture gap at the bottom) is the hard
      # height limit. Fit the piece inside (preferred_w × band height) preserving its own aspect so
      # it never reaches the ceiling or the furniture. When the band — not the furniture — caps the
      # width, record that so QA can tell a genuinely small piece from a wall-constrained one.
      band_h = vertical_band[:height]

      ratio = art_native.height.to_f / art_native.width

      if band_h.positive? && preferred_w.positive? && (preferred_w * ratio) > band_h
        w = [(band_h / ratio).to_i, 1].max
        { w: w, h: band_h, width_limited_by_wall: true, max_group_width_px: w }
      else
        { w: preferred_w, h: (preferred_w * ratio).to_i,
          width_limited_by_wall: false, max_group_width_px: preferred_w }
      end
    end

    # The vertical band the art may occupy for this room: from the ceiling clearance down to the
    # furniture gap. Falls back to the wall zone for rooms/measurements without a ceiling anchor.
    def vertical_band
      m    = @template.fetch("measurements")
      zone = m["wall_zone"] || {}
      ppi  = pixels_per_inch

      ceiling_y = m["ceiling_y_px"]
      sofa_top  = m["furniture_top_edge_y_px"]

      if ceiling_y.present? && sofa_top.present? && @piece.room_type == "seated_room"
        top    = ceiling_y.to_i + (ceiling_clearance_inches * ppi).to_i
        bottom = sofa_top.to_i - (gap_inches * ppi).to_i
      else
        top    = zone["y"].to_i
        bottom = zone["y"].to_i + zone["height"].to_i
      end

      { top: top, bottom: bottom, height: [bottom - top, 0].max }
    end

    def gap_inches = 9.0

    def ceiling_clearance_inches
      KnowledgeBase::RuleSet.load("eye_level")
                            .rules.dig("ceiling_clearance", "formula_inches").to_f
    end

    def compute_position(art_dims)
      m = @template.fetch("measurements")

      # === Horizontal centering across wall zone / furniture ===
      wall_zone = m["wall_zone"] || {}
      wall_center_x = wall_zone["x"].to_i + (wall_zone["width"].to_i / 2)
      x = wall_center_x - (art_dims[:w] / 2)

      # === Vertical position — eye-level rule (§2.10) + general drop (P2-P14) ===
      ppi = pixels_per_inch
      eye_rules = KnowledgeBase::RuleSet.load("eye_level").rules

      by_room = eye_rules["by_room_type"].fetch(@piece.room_type)
      anchor_key = by_room["anchor"]
      anchor_y = m.fetch(anchor_key) do
        raise TemplateError, "Template is missing measurement '#{anchor_key}' for " \
                             "room_type=#{@piece.room_type}."
      end

      center_y = if @piece.room_type == "seated_room"
                   inches_above = by_room["formula_inches"].to_f
                   furniture_top_y = anchor_y.to_i
                   furniture_top_y - (inches_above * ppi).to_i - (art_dims[:h] / 2)
      else
                   anchor_y.to_i
      end

      drop_inches = eye_rules["general_drop"]["formula_inches"].to_f.abs
      drop_px = (drop_inches * ppi).to_i
      center_y += drop_px

      y = center_y - (art_dims[:h] / 2)

      # === Furniture 8-10" gap check (§2.11) — validate, don't silently fix ===
      gap_px = nil
      if @piece.room_type == "seated_room"
        gap_px = anchor_y.to_i - (y + art_dims[:h])
        gap_in = gap_px.to_f / ppi
        if gap_in < 8 || gap_in > 10
          target_gap_px = (gap_inches * ppi).to_i
          y = anchor_y.to_i - target_gap_px - art_dims[:h]
          gap_px = target_gap_px
        end
      end

      # Never let the piece ride up into the ceiling clearance: keep it inside the band.
      band = vertical_band
      y = y.clamp(band[:top], [band[:bottom] - art_dims[:h], band[:top]].max)

      { x: x, y: y, gap_px: gap_px, drop_inches: drop_inches,
        band_top_px: band[:top], band_bottom_px: band[:bottom] }
    end

    def paste_art_on_template(art, x:, y:, w:, h:)
      template_img = Vips::Image.new_from_file(Pipeline::KB_ROOT.join(@template["image_path"]).to_s)
      resized_art  = art.resize(w.to_f / art.width)
      template_img.composite2(resized_art, :over, x: x, y: y)
    end

    def clamp_to_bounds(art_dims, x, y)
      m    = @template["measurements"]
      zone = m["wall_zone"] || {}
      zx = zone["x"].to_i
      zy = zone["y"].to_i
      zw = zone["width"].to_i
      zh = zone["height"].to_i

      # Keep the art inside the placement zone (never the ceiling/furniture above/below it).
      if zw.positive? && zh.positive?
        max_x = zx + [zw - art_dims[:w], 0].max
        max_y = zy + [zh - art_dims[:h], 0].max
        return [x.clamp(zx, max_x), y.clamp(zy, max_y)]
      end

      tw = m["image_width_px"].to_i
      th = m["image_height_px"].to_i
      return [x, y] if tw <= 0 || th <= 0

      max_x = [tw - art_dims[:w], 0].max
      max_y = [th - art_dims[:h], 0].max
      [x.clamp(0, max_x), y.clamp(0, max_y)]
    end

    def pixels_per_inch
      m = @template.fetch("measurements")
      value = m.fetch("pixels_per_inch").to_i
      raise TemplateError, "Template '#{@piece.scene_spec_id}' has invalid pixels_per_inch" if value <= 0

      if m["calibrated"] == false
        # A speculative dry-run may proceed on the uncalibrated estimate (the dossier surfaces the
        # flag); a committed run must not place art on unverified pixel math.
        unless Workflow::RunMode.speculative?
          raise TemplateError, "Template '#{@piece.scene_spec_id}' pixels_per_inch is uncalibrated"
        end
      end

      value
    end

    def write_output(img)
      dst = Rails.root.join("tmp", "composites", "#{@piece.id}_#{Time.current.to_i}.png")
      dst.dirname.mkpath
      img.write_to_file(dst.to_s)
      dst.to_s
    end

    def measurements_summary(art_dims, x, y, pos)
      m = @template["measurements"]
      wall_area = m["wall_zone"]["width"].to_i * m["wall_zone"]["height"].to_i
      art_area  = art_dims[:w] * art_dims[:h]
      ceiling_y = m["ceiling_y_px"]
      {
        art_width_px:  art_dims[:w],
        art_height_px: art_dims[:h],
        x_px: x, y_px: y,
        pixels_per_inch: m["pixels_per_inch"],
        calibrated: m["calibrated"] != false,
        coverage_fraction: (art_area.to_f / wall_area).round(4),
        eye_level_anchor: m[KnowledgeBase::RuleSet.load("eye_level").rules["by_room_type"][@piece.room_type]["anchor"]],
        furniture_width_px: m["furniture_width_px"],
        group_width_px: art_dims[:w],
        group_width_limited_by_wall: art_dims[:width_limited_by_wall],
        max_group_width_px: art_dims[:max_group_width_px],
        furniture_gap_px: pos[:gap_px],
        drop_applied_inches: pos[:drop_inches],
        ceiling_y_px: ceiling_y,
        ceiling_gap_px: ceiling_y.present? ? (y - ceiling_y.to_i) : nil,
        ceiling_clearance_inches: ceiling_clearance_inches,
        band_top_px: pos[:band_top_px],
        band_bottom_px: pos[:band_bottom_px],
        framed: framed?,
        frame_material_category: attr(:frame_material_category),
        frame_material_finish: attr(:frame_material_finish),
        frame_contour: attr(:frame_contour),
        matting_technique: attr(:matting_technique)
      }
    end

    def framed? = attr(:frame_material_category).present?

    def attr(name) = @piece.respond_to?(name) ? @piece.public_send(name) : nil
  end
end
