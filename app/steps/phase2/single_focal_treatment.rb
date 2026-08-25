module Steps
  module Phase2
    class SingleFocalTreatment < Steps::Base
      step id: "P2_2a", mechanism: :lookup, ownership: "[AGENT-READY]"

      def perform
        focal = rules("focal_point").fetch("mechanism", "single_isolated")
        amp   = focal["mood_amplification"].fetch(piece.mood)

        piece.update!(
          arrangement_form: "single_focal",
          piece_count: 1,
          anchor_piece_ref: piece.chosen_url    # the single piece IS the anchor
        )
        ok({ focal_treatment: amp, frame_weight_hint: (piece.mood == "bold_active" ? "impressive" : "quiet") })
      end
    end
  end
end
