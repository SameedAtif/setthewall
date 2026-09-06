module Agents
  # P2_1–P2_6 — placement. The strongest agent: P2_6 is arithmetic against page citations and is
  # re-derived rather than trusting the step's own report. (Lookup-step rule-table re-derivation is
  # deferred; those steps pass and are re-checked at P2_6.)
  class PlacementQa < Base
    agent id: "placement_qa", covers: %w[P2_1 P2_2a P2_2b P2_2c P2_2d P2_2e P2_3 P2_4 P2_4b P2_5 P2_6]

    def evaluate
      @step_id == "P2_6" ? composite : lookup_pass
    end

    private

    def lookup_pass
      [pass("#{@step_id} is a lookup step whose output derives from the rule tables and is " \
            "re-checked at P2_6.", [cite("coverage_cap.rules")])]
    end

    def composite
      m = data["measurements"] || {}
      ppi = m["pixels_per_inch"].to_f
      findings = []

      # Coverage cap — p. 51. Binary, NOT overridable (SR6).
      cf  = m["coverage_fraction"].to_f
      cap = rules("coverage_cap").rules.dig("cap", "default_max_fraction").to_f
      if cf > cap && cf < 0.95
        findings << blocking(
          "Coverage fraction #{cf.round(3)} falls in the forbidden mid-band. Coverage is binary: " \
          "stay under two-thirds or commit fully maximalist.",
          [cite("coverage_cap.rules.cap")], { coverage_fraction: cf })
      else
        findings << pass("Coverage fraction #{cf.round(3)} is outside the forbidden mid-band.",
                         [cite("coverage_cap.rules.cap")])
      end

      # Eye-level drop — p. 63. Most people hang too high.
      drop = rules("eye_level").rules.dig("general_drop", "formula_inches").to_f.abs
      unless m["drop_applied_inches"].to_f.between?(drop - 0.6, drop + 0.6)
        findings << blocking(
          "General eye-level drop of #{drop}\" was not applied (found " \
          "#{m['drop_applied_inches']}\"). Hanging too high is the most common placement mistake.",
          [cite("eye_level.rules.general_drop")])
      end

      # Furniture gap — p. 63, seated rooms only.
      if @run.piece_record&.room_type == "seated_room" && ppi.positive?
        gap = m["furniture_gap_px"].to_f / ppi
        findings << if gap.between?(8.0, 10.0)
          pass("Furniture gap #{gap.round(1)}\" sits in the 8-10\" band.", [cite("spacing.rules")])
        else
          blocking("Furniture gap is #{gap.round(1)}\", outside the 8-10\" band.", [cite("spacing.rules")],
                   { gap_inches: gap.round(2) })
        end
      end

      # Group width vs furniture — p. 63.
      if m["group_width_px"] && m["furniture_width_px"]
        ratio = m["group_width_px"].to_f / m["furniture_width_px"].to_f
        unless ratio.between?(0.5, 1.0)
          findings << blocking(
            "Group width is #{(ratio * 100).round}% of the furniture below. It must be no wider " \
            "than the furniture and at least half its length.",
            [cite("spacing.rules")], { ratio: ratio.round(3) })
        end
      end

      findings
    end
  end
end
