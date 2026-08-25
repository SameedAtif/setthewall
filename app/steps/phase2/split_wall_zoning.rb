module Steps
  module Phase2
    class SplitWallZoning < Steps::Base
      step id: "P2_2c", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { split_technique: (chair_rail|border|paint_line|backing_panel),
      #            zones: [ { branch: (single|set), piece_count: N, anchor_url: '...' } , ... ] }
      def perform
        rule = rules("placement_branch").fetch("by_space_math", "split_wall")

        zones = context.fetch(:zones, [])
        if zones.empty?
          return fail_step("split_wall requires at least one zone in context[:zones]", {})
        end

        # Each zone recursively re-uses 2a/2b logic — a zone is treated as a separate wall.
        zone_results = zones.map do |z|
          {
            branch: z[:branch],
            piece_count: z[:piece_count]
            # Focal/grouping recorded per zone; the actual sub-step (2a or 2b) doesn't run
            # separately here — the compositor treats each zone as its own placement region.
          }
        end

        piece.update!(
          arrangement_form: "split_wall_#{context.fetch(:split_technique, 'chair_rail')}",
          piece_count: zones.sum { |z| z[:piece_count].to_i },
          composite_measurements: (piece.composite_measurements || {}).merge("zones" => zone_results)
        )

        ok({ split_technique: context[:split_technique], zones: zone_results,
             citation: rule["citation"] })
      end
    end
  end
end
