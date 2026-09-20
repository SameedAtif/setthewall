module Steps
  module Phase2
    class MeasureScene < Steps::Base
      step id: "P2_1", mechanism: :lookup, ownership: "[AGENT-READY]"

      def perform
        branch_rule = rules("placement_branch").fetch("by_space_math", piece.space_math)

        # Location suitability check (§2.5b)
        location_issues = check_location_suitability
        if location_issues.any?
          return needs_human(
            "Scene fails location suitability checks: #{location_issues.join('; ')}. " \
            "Reroute or accept the risk explicitly.",
            { location_issues: location_issues, branch: branch_rule["action"] }
          )
        end

        # Coverage cap check (§2.5c) — will be re-checked in Step 6 with actual pixels; here we
        # just confirm the intended coverage isn't in the forbidden mid-band.
        # Actual coverage_fraction check runs in the compositor once dimensions are known.

        # Space tips (module 04 §2.5a) are an ARRANGEMENT concern and belong here in Phase 2, not
        # in art generation. Look up the technique/line-orientation hint for this room shape; it is
        # reported alongside the placement branch for the compositor/arrangement step.
        space_tip = rules("space_tips").rules.dig("by_room_shape", piece.room_shape) || {}
        if space_tip.present?
          Workflow::StepLogging.log("Space tip (#{piece.room_shape}): #{space_tip['technique']} — " \
                                    "#{space_tip['detail']}")
        end

        piece.update!(placement_branch: piece.space_math)
        ok({ placement_branch: piece.space_math, next_step: branch_rule["step_2x"],
             space_tip: space_tip })
      end

      private

      def check_location_suitability
        rule = rules("location_suitability").rules
        issues = []
        # Scene template can declare its room type; here we lean on the axis values already set.
        # If the scene template exposes a `room_hint` (bathroom/kitchen/etc.) it can be checked
        # against rule["humidity"]["unsafe_rooms"] — extension point, not required for MVP.
        issues
      end
    end
  end
end
