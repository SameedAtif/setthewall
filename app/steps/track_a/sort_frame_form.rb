module Steps
  module TrackA
    class SortFrameForm < Steps::Base
      step id: "A4",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms]"

      # context: { reference_images:, mood: }  — mood must already be confirmed by A2
      def perform
        mood = context.fetch(:mood)

        result = Pipeline::Json.normalize(
          RubyLLM.chat(model: Pipeline::VISION_MODEL)
                 .with_schema(Schemas::TrackA::FrameFormSchema)
                 .ask(prompt("a4_frame_form", mood: mood),
                      with: context.fetch(:reference_images)).content
        )

        if result.empty?
          return needs_human(
            "A4 got no frame form back from the vision model (empty response). Re-run A4.",
            { result: result, note: nil, recommended_action: "confirm" }
          )
        end

        note =
          if result["consistency"] == "mixed"
            "Framing was mixed across references; resolved using the mood tiebreaker " \
            "(mood=#{mood}). Bold moods tolerate mixed framing; calm moods should converge."
          else
            "Framing was consistent across references."
          end

        needs_human("Confirm frame form: #{result['frame_form']}. #{note}",
                    { result: result, note: note, recommended_action: "confirm" })
      end
    end
  end
end
