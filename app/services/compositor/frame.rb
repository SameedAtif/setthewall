module Compositor
  # Renders the piece's frame + mat deterministically onto the artwork before it is pasted into a
  # scene. Reads the frame attributes decided at P2_4 (frame_material_category / _finish, contour,
  # matting_technique) and the appearance constants in knowledge_base/rules/frame_appearance.yml.
  #
  # Layering, outside in: frame moulding → mat → artwork. A rounded contour rounds the OUTER corner
  # of the frame (the wall shows through the corner), matching the "softer perimeter" reading.
  class Frame
    def self.apply(art:, piece:) = new(art: art, piece: piece).apply

    def initialize(art:, piece:)
      @art   = art
      @piece = piece
      @rules = KnowledgeBase::RuleSet.load("frame_appearance").rules
    end

    def apply
      return @art unless frame_color

      rounded(framed_image)
    end

    private

    def frame_color
      return @frame_color if defined?(@frame_color)

      @frame_color = begin
        category = @piece.respond_to?(:frame_material_category) ? @piece.frame_material_category.to_s : ""
        category.blank? ? nil : frame_color_for(category)
      end
    end

    def frame_color_for(category)
      if category == "metal"
        finish = @piece.frame_material_finish.to_s.presence || "black_metal"
        @rules.dig("frame", "metal", finish) || @rules.dig("frame", "metal", "black_metal")
      else
        @rules.dig("frame", category)
      end
    end

    def technique = @rules.dig("mat_technique", @piece.matting_technique.to_s) || {}
    def mat? = technique.fetch("mat", true)

    def frame_width_px = ((@art.width * @rules.dig("border_fractions", "frame")).round).clamp(1, 10_000)
    def mat_width_px
      return 0 unless mat?

      ((@art.width * @rules.dig("border_fractions", "mat")).round).clamp(0, 10_000)
    end

    def framed_image
      aw = @art.width
      ah = @art.height
      fw = frame_width_px
      mw = mat_width_px
      pad = fw + mw

      canvas = solid(aw + (2 * pad), ah + (2 * pad), frame_color)

      if mat?
        canvas = canvas.composite2(solid(aw + (2 * mw), ah + (2 * mw), mat_color),
                                   :over, x: fw, y: fw)
        canvas = add_inner_mat(canvas, aw, ah, fw, mw) if technique.fetch("layers", 1).to_i >= 2
      end

      canvas.composite2(flat_art, :over, x: pad, y: pad)
    end

    # double_stepped_mat: reveal a strip of the inner mat inside the outer one.
    def add_inner_mat(canvas, aw, ah, fw, mw)
      reveal = (mw * @rules.dig("mat", "double_step_reveal_fraction").to_f).round
      reveal = mw - 1 if reveal >= mw
      return canvas if reveal <= 0

      inner_w = aw + (2 * (mw - reveal))
      inner_h = ah + (2 * (mw - reveal))
      canvas.composite2(solid(inner_w, inner_h, @rules.dig("mat", "inner")),
                        :over, x: fw + reveal, y: fw + reveal)
    end

    def mat_color = @rules.dig("mat", technique.fetch("color", "neutral"))

    def flat_art
      art = @art.colourspace("srgb")
      art = art.flatten(background: [255, 255, 255]) if [2, 4].include?(art.bands)
      art
    end

    def rounded(img)
      return img unless @piece.frame_contour.to_s == "rounded"

      radius = (@rules.fetch("corner_radius_fraction").to_f * [img.width, img.height].min).round
      return img if radius < 1

      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="#{img.width}" height="#{img.height}">) +
            %(<rect x="0" y="0" width="#{img.width}" height="#{img.height}" ) +
            %(rx="#{radius}" ry="#{radius}" fill="#ffffff"/></svg>)
      mask = Vips::Image.svgload_buffer(svg).extract_band(0)
      img.bandjoin(mask)
    rescue Vips::Error
      img
    end

    def solid(width, height, hex)
      r, g, b = rgb(hex)
      Vips::Image.black(width, height, bands: 3).linear(1, [r, g, b]).cast("uchar")
           .copy(interpretation: :srgb)
    end

    def rgb(hex)
      value = hex.to_s.delete("#")
      [value[0, 2], value[2, 2], value[4, 2]].map { |pair| pair.to_i(16) }
    end
  end
end
