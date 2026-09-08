module Steps
  module TrackA
    class ValidateStyle < Steps::Base
      step id: "A0",
           mechanism: :llm_text,
           ownership: "[AGENT-READY for the research — human confirms the go/no-go]"

      # context: { style_name:, style_slug: }
      def perform
        brief = prompt("a0_style_validation", style_name: context.fetch(:style_name))

        result = Search::ReasonedRunner.call(
          model: Pipeline::TEXT_MODEL,
          schema: Schemas::TrackA::StyleValidationSchema,
          task: "You are validating whether a wall-art style is worth committing production to.",
          question: brief,
          max_rounds: 8,  # A0's methodology needs: 1 style search + 2-3 adjacent terms +
          # 1 cross-check platform + competition-density lookups
          min_rounds: 4   # search floor — the cross-check + competition lookups are not optional
        )

        content = result[:content]
        breadth_note =
          if content["breadth_assessment"] == "fragments_into_substyles"
            "⚠ #{context.fetch(:style_name)} FRAGMENTED into #{content["findings"]&.size || "?"} " \
            "distinct sub-themes — this is not one coherent style. Read the breakdown before " \
            "deciding; the agent's single pick is #{content["single_recommended_focus"].inspect}, " \
            "not the name you originally validated."
          else
            "Resolved as one coherent style. Agent's pick: " \
            "#{content["single_recommended_focus"].inspect}."
          end

        style_name_used =
          if content["breadth_assessment"] == "fragments_into_substyles"
            content["single_recommended_focus"]
          else
            context.fetch(:style_name)
          end

        needs_human(
          "#{breadth_note} Read the demand-to-competition findings and make the go/no-go call. " \
          "The agent ran #{result[:search_calls_made]} live searches, tried " \
          "#{content["cross_check_attempts"]&.size || 0} route(s) for the Trends/Pinterest " \
          "cross-check; committing a week's production to this style is your decision, not the agent's.",
          { findings: content, search_calls_made: result[:search_calls_made],
            min_rounds_met: result[:min_rounds_met], brief: brief,
            style_name_used: style_name_used, searches: result[:searches] }
        )
      rescue Search::NoSearchPerformedError => e
        fail_step("A0 could not complete: #{e.message}", { brief: brief })
      end
    end
  end
end
