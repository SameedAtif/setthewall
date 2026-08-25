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
          max_rounds: 8   # A0's methodology needs: 1 style search + 2-3 adjacent terms +
                           # 1 cross-check platform + competition-density lookups
        )

        needs_human(
          "Read the demand-to-competition findings and make the go/no-go call. The agent ran " \
          "#{result[:search_calls_made]} live searches; committing a week's production to this " \
          "style is your decision, not the agent's.",
          { findings: result[:content], search_calls_made: result[:search_calls_made], brief: brief }
        )
      rescue Search::NoSearchPerformedError => e
        fail_step("A0 could not complete: #{e.message}", { brief: brief })
      end
    end
  end
end
