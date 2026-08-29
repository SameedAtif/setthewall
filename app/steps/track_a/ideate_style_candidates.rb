module Steps
  module TrackA
    class IdeateStyleCandidates < Steps::Base
      step id: "A_IDEATE",
           mechanism: :llm_text,
           ownership: "[AGENT-READY for the research — human picks which candidate to validate]"

      # context: { direction: (optional String — a loose steer, e.g. "something calm and neutral"),
      #            candidate_count: (optional Integer) }
      def perform
        constraints = rules("ideation_constraints").rules
        count = [context.fetch(:candidate_count, constraints["candidate_count"]["default"]).to_i,
                 constraints["candidate_count"]["max"]].min

        direction_clause = if context[:direction].present?
                             "Steer toward this rough direction if it fits current trends: " \
                             "#{context[:direction]}. Don't force it if nothing trending matches."
        else
                             "No specific direction requested — survey broadly across current " \
                             "home-decor and wall-art trends."
        end

        result = Search::ReasonedRunner.call(
          model: Pipeline::TEXT_MODEL,
          schema: Schemas::TrackA::StyleIdeationSchema,
          task: "You are surveying current wall-art style trends to surface candidates for a " \
                "print business — a broad, shallow pass, not a deep validation of any one style.",
          question: prompt("a_ideate_style_candidates",
                           candidate_count: count, direction_clause: direction_clause),
          max_rounds: 10   # broader survey than A0's single-style deep dive, so a larger budget
        )

        candidates = result[:content]["candidates"] || []
        min_sources = constraints["source_diversity"]["min_independent_sources_per_candidate"]
        weak = candidates.select { |c| c["independent_source_count"].to_i < min_sources }

        needs_human(
          "#{candidates.size} candidate(s) surveyed (#{result[:search_calls_made]} live searches). " \
          "#{weak.any? ? "#{weak.size} candidate(s) below the #{min_sources}-source minimum — " \
                          "weaker signal, shown for completeness." : 'All candidates meet the ' \
                          "source-diversity bar."} " \
          "Pick ONE and run it through the existing Track A pipeline: " \
          "`bin/rails pipeline:track_a style_slug=<slug> style_name=\"<chosen name>\"`. " \
          "This step is NOT validation — A0 still runs in full against whichever you pick.",
          { candidates: candidates, weak_candidates: weak.map { |c| c["name"] },
            survey_notes: result[:content]["survey_notes"] }
        )
      rescue Search::NoSearchPerformedError => e
        fail_step("Ideation could not complete: #{e.message}", {})
      end
    end
  end
end
