module Steps
  module TrackA
    class SceneResearch < Steps::Base
      step id: "A7", mechanism: :llm_text, ownership: "[AGENT-READY]"

      RECURRENCE_MIN = 3

      # context: { style_slug:, style_name: }
      def perform
        question = prompt("a_scene_research", style_name: context.fetch(:style_name))

        result = Search::ReasonedRunner.call(
          model: Pipeline::TEXT_MODEL,
          schema: Schemas::TrackA::SceneResearchSchema,
          task: "You are researching the recurring scene patterns of a wall-art style from real " \
                "listings.",
          question: question,
          max_rounds: 8,
          min_rounds: 4
        )

        content  = result[:content]
        patterns = Array(content["scene_patterns"])
        recurring = patterns.select { |p| p["recurs_across_shops"].to_i >= RECURRENCE_MIN }
        rejected  = patterns.select { |p| p["recurs_across_shops"].to_i < RECURRENCE_MIN }
                            .map { |p| p.merge("reason" => "below #{RECURRENCE_MIN}-shop minimum") }

        data = {
          shops_sampled: content["shops_sampled"].to_i,
          scene_patterns: recurring,
          rejected_patterns: rejected
        }

        KnowledgeBase::StyleSpecWriter.write_scene_research(context.fetch(:style_slug), data)

        ok({ scene_research: data, prompt: question, searches: result[:searches] })
      rescue Search::NoSearchPerformedError => e
        fail_step("A7 scene research could not complete: #{e.message}", {})
      end
    end
  end
end
