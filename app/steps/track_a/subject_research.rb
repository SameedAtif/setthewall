module Steps
  module TrackA
    class SubjectResearch < Steps::Base
      step id: "A6", mechanism: :llm_text, ownership: "[AGENT-READY]"

      RECURRENCE_MIN = 3

      # context: { style_slug:, style_name: }
      def perform
        result = Search::ReasonedRunner.call(
          model: Pipeline::TEXT_MODEL,
          schema: Schemas::TrackA::SubjectResearchSchema,
          task: "You are researching the recurring subjects of a wall-art style from real listings.",
          question: prompt("a_subject_research", style_name: context.fetch(:style_name)),
          max_rounds: 8,
          min_rounds: 4
        )

        content  = result[:content]
        subjects = Array(content["subjects"])
        recurring = subjects.select { |s| s["recurs_across_shops"].to_i >= RECURRENCE_MIN }
        rejected  = subjects.select { |s| s["recurs_across_shops"].to_i < RECURRENCE_MIN }
                            .map { |s| s.merge("reason" => "below #{RECURRENCE_MIN}-shop minimum") }

        data = {
          shops_sampled: content["shops_sampled"].to_i,
          recurring_subjects: recurring,
          rejected_subjects: rejected
        }

        KnowledgeBase::StyleSpecWriter.write_subject_research(context.fetch(:style_slug), data)

        ok({ subject_research: data })
      rescue Search::NoSearchPerformedError => e
        fail_step("A6 subject research could not complete: #{e.message}", {})
      end
    end
  end
end
