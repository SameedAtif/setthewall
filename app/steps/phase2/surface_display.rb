module Steps
  module Phase2
    class SurfaceDisplay < Steps::Base
      step id: "P2_2e", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { piece_count: N, heights_used: [Integer], surface_type: (mantel|shelf|console|windowsill) }
      def perform
        rule = rules("placement_branch").fetch("by_space_math", "surface")

        count = context.fetch(:piece_count, 1).to_i
        heights = Array(context[:heights_used])

        # Validation from the source doc: "at least two distinct height levels are present if
        # more than one piece is shown; no two pieces are perfectly flush unless that flatness
        # is the deliberate look for this mood."
        if count > 1 && heights.uniq.size < 2
          return needs_human(
            "Surface display with #{count} pieces has only #{heights.uniq.size} distinct height " \
            "level(s). Per §2.5, vary heights using stands, risers, or stacked objects. " \
            "Confirm this flat look is deliberate for this mood, or add height variation.",
            { piece_count: count, heights_used: heights, mood: piece.mood }
          )
        end

        piece.update!(
          arrangement_form: count > 1 ? "loose_triangle" : "single_leaned",
          piece_count: count
        )

        ok({ surface_type: context[:surface_type], piece_count: count,
             distinct_heights: heights.uniq.size, citation: rule["citation"] })
      end
    end
  end
end
