module Steps
  module Phase2
    class Composite < Steps::Base
      step id: "P2_6",
           mechanism: :deterministic_tool,
           ownership: "[DETERMINISTIC PLACEMENT + AI PHOTOREAL PASS — placement math is never " \
                      "delegated to a model]"

      def perform
        result = Compositor::Runner.call(piece: piece)

        # Deterministic placement/frame is the underlay; an optional AI pass re-renders the frame
        # photorealistically while keeping the composition. Falls back to the deterministic image.
        output_path = Compositor::PhotorealPass.call(path: result.output_path, piece: piece) ||
                      result.output_path

        piece.update!(
          composite_url: output_path,
          composite_measurements: result.measurements
        )

        # Coverage cap check (§2.5c) runs against the FINAL measurements
        cap_rule = rules("coverage_cap").fetch("cap")
        cf = result.measurements[:coverage_fraction].to_f
        forbidden = cf > cap_rule["default_max_fraction"].to_f && cf < 0.95
        if forbidden
          return fail_step(
            "Coverage cap violation: coverage_fraction=#{cf.round(3)} is in the forbidden mid-band " \
            "(>0.6667 and <0.95). Per §2.5c, this reads as a mistake. Reduce piece size or commit " \
            "fully maximalist.",
            { coverage_fraction: cf, allowed_regions: cap_rule["validation"]["allowed_regions"] }
          )
        end

        ok({ composite_url: output_path, measurements: result.measurements })
      rescue Compositor::TemplateError => e
        fail_step("Compositor failed: #{e.message}. Scene template measurements likely missing " \
                  "or wrong — see knowledge_base/scene_templates/#{piece.scene_spec_id}.yml.", {})
      end
    end
  end
end
