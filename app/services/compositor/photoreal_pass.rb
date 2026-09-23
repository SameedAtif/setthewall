module Compositor
  # Optional post-pass over a finished composite. The deterministic compositor draws a flat frame
  # and mat (hard edges, no depth), which reads as obviously edited. When an image-generation
  # provider is configured, hand the composite back to the model with an edit instruction that
  # KEEPS the composition — room, furniture, and the artwork's exact position and size — and only
  # renders the frame/mat as a real physical object. Placement stays deterministic; only the frame
  # appearance is delegated.
  #
  # Returns the refined image path, or nil to fall back to the deterministic composite (no provider,
  # empty result, or any error).
  class PhotorealPass
    def self.call(path:, piece:) = new(path: path, piece: piece).call

    def initialize(path:, piece:)
      @path  = path
      @piece = piece
    end

    def call
      return nil if @path.blank? || !File.exist?(@path.to_s)

      result = ImageGeneration::Adapter.build.generate(prompt: prompt, n: 1,
                                                       style_reference: [@path.to_s])
      url = Array(result.urls).first
      url.blank? ? nil : localize(url)
    rescue StandardError => e
      Rails.logger.warn("Compositor::PhotorealPass skipped: #{e.class}: #{e.message}")
      nil
    end

    private

    def localize(url)
      return url if File.exist?(url.to_s)

      ext = File.extname(URI.parse(url.to_s).path).presence || ".png"
      dst = Rails.root.join("tmp", "composites", "photoreal_#{@piece.id}_#{Time.current.to_i}#{ext}")
      response = Faraday.get(url)
      return nil unless response.success?

      dst.dirname.mkpath
      dst.binwrite(response.body)
      dst.to_s
    rescue StandardError
      nil
    end

    def prompt
      <<~PROMPT
        Photorealistic edit of this interior mockup of a framed art print hanging on a wall.
        Keep the composition EXACTLY as it is: same room, same furniture, same props, the same
        artwork image, and the artwork in the SAME position and SAME size on the wall.
        Render the picture frame and mat as a real physical object photographed in the room:
        #{frame_clause} with realistic depth, bevel and a subtle drop shadow, lit consistently
        with the room. Do not move, resize or restyle anything else, and do not alter the artwork
        itself or its colours. No text, no watermark, no signature.
      PROMPT
    end

    def frame_clause
      case attr(:frame_material_category).to_s
      when "metal"
        { "gold" => "a slim gold metal frame",
          "silver_aluminum" => "a slim brushed-aluminium frame",
          "black_metal" => "a slim matte black metal frame" }
          .fetch(attr(:frame_material_finish).to_s, "a slim metal frame")
      when "wood"           then "a natural wood moulding frame"
      when "ornate_carved"  then "an ornate carved gilt frame"
      when "no_frame_canvas" then "no frame (a gallery-wrapped canvas)"
      when "clip_frame"     then "a simple clear clip frame"
      when "colored_painted" then "a painted frame"
      else "a picture frame"
      end
    end

    def mat_clause
      case attr(:matting_technique).to_s
      when "no_mat", "close_framing" then "no mat"
      when "colored_mat"             then "a colored mat"
      when "double_stepped_mat"      then "a double-step mat"
      else "a neutral off-white mat"
      end
    end

    def attr(name) = @piece.respond_to?(name) ? @piece.public_send(name) : nil
  end
end
