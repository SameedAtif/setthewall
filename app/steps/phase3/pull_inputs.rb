module Steps
  module Phase3
    class PullInputs < Steps::Base
      step id: "P3_1", mechanism: :lookup, ownership: "[AGENT-READY]"

      REQUIRED_PIECE_FIELDS = %w[
        chosen_url composite_url frame_material_category frame_contour matting_technique
        color_role_confirmed mood content_type room_type
      ].freeze

      def perform
        missing = REQUIRED_PIECE_FIELDS.select { |f| piece.send(f).blank? }
        if missing.any?
          return fail_step(
            "Phase 3 cannot start — required Phase 2 outputs are missing: #{missing.join(', ')}. " \
            "Complete module 04's Steps 4, 4b, 5, 6 for this piece first.",
            { missing_fields: missing }
          )
        end

        ok({
          chosen_url: piece.chosen_url,
          composite_url: piece.composite_url,   # This IS the Lifestyle photo (§2.4a)
          frame_summary: {
            category: piece.frame_material_category,
            finish: piece.frame_material_finish,
            contour: piece.frame_contour,
            matting: piece.matting_technique
          },
          style_summary: {
            style_name: spec.name, mood: piece.mood,
            content_type: piece.content_type, color_role: piece.color_role_confirmed
          },
          dimensions: piece.composite_measurements&.slice("art_width_px", "art_height_px")
        })
      end
    end
  end
end
