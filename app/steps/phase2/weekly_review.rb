module Steps
  module Phase2
    class WeeklyReview < Steps::Base
      step id: "P2_7",
           mechanism: :human,
           ownership: "[HUMAN ONLY — agent may summarize data, not decide]"

      # context: { performance_summary: (String or Hash) }
      # Populated by module 07's weekly-review export job before this step runs.
      def perform
        summary = context[:performance_summary]

        needs_human(
          "Weekly review — carry the previous week's Phase 3 performance data forward and decide " \
          "whether next week's Step 0 REPEATS, EXTENDS, or ROTATES the style/scene combination. " \
          "Per the ownership tag, the agent may SUMMARIZE the numbers but not decide.",
          { performance_summary: summary,
            available_options: %w[repeat extend rotate],
            grounding: "Phase 2 §3 STEP 7 — human interprets sales/view data; agent does not" }
        )
      end
    end
  end
end
