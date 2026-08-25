module Steps
  module Phase2
    class NookFit < Steps::Base
      step id: "P2_2d", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { nook_dimensions_px: { width:, height: }, piece_count: N }
      def perform
        rule = rules("placement_branch").fetch("by_space_math", "nook")

        count = context.fetch(:piece_count, 1).to_i
        # Nook must accommodate piece-to-piece spacing (§2.11 general rule) if a group.
        if count > 1
          spacing_rule = rules("spacing").fetch("rules", "piece_to_piece_general")
          # No hard pixel check here — the compositor validates fit in Step 6.
        end

        piece.update!(
          arrangement_form: "nook_fit",
          piece_count: count,
          anchor_piece_ref: count == 1 ? piece.chosen_url : context[:anchor_url]
        )

        ok({ nook_dimensions: context[:nook_dimensions_px], piece_count: count,
             citation: rule["citation"] })
      end
    end
  end
end
