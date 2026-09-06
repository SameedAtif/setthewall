module Steps
  module TrackA
    class SortMood < Steps::Base
      step id: "A2",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms]"

      REQUIRED_MARKERS = 2   # of 4
      REQUIRED_IMAGES  = 3

      # context: { reference_images: [urls] }
      def perform
        images = context.fetch(:reference_images)

        result = Pipeline::Json.normalize(
          RubyLLM.chat(model: Pipeline::VISION_MODEL)
                 .with_schema(Schemas::TrackA::MoodSchema)
                 .ask(prompt("a2_mood"), with: images).content
        )

        if result.empty?
          return needs_human(
            "A2 got no scorecard back from the vision model (empty response). Re-run A2.",
            { result: result, recommended_action: "return_to_a1" }
          )
        end

        if result["mood"] == "mixed"
          return needs_human(
            "Mood scorecard came back mixed. Per the rule, do not force a call — narrow the " \
            "reference set and re-run A1 rather than picking one.",
            { result: result, recommended_action: "return_to_a1" }
          )
        end

        unless validation_passes?(result)
          return needs_human(
            "Mood proposed as #{result['mood']}, but the validation bar was not met " \
            "(needs 3+ clearly supporting images across 2+ of the 4 markers). " \
            "Consider narrowing the reference set.",
            { result: result, recommended_action: "return_to_a1" }
          )
        end

        needs_human(
          "Confirm mood: #{result['mood']}. Check the marker evidence before accepting.",
          { result: result, recommended_action: "confirm" }
        )
      end

      private

      def validation_passes?(r)
        r["markers_supporting_chosen_mood"].to_i >= REQUIRED_MARKERS &&
          r["clearly_supporting_images"].to_i >= REQUIRED_IMAGES
      end
    end
  end
end
