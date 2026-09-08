module Art
  # Computes the honest print-size ceiling from the image generator's maximum output resolution,
  # so a listing never offers a size the generator cannot render at 300 DPI (the wall-art target).
  # IMAGE_GEN_MAX_OUTPUT_PX is `volatility: live` — re-verify against the current generator's docs.
  class PrintResolution
    DPI = 300

    def self.max_output_px
      ENV.fetch("IMAGE_GEN_MAX_OUTPUT_PX", "4096").to_i
    end

    def self.max_inches_per_dimension
      max_output_px.to_f / DPI
    end

    def self.oversized?(width_in:, height_in:)
      max = max_inches_per_dimension
      width_in.to_f > max || height_in.to_f > max
    end
  end
end
