module Steps
  module TrackA
    class SortContentType < Steps::Base
      step id: "A3",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackA::ContentTypeSchema)
                        .ask(prompt("a3_content_type"), with: context.fetch(:reference_images))
                        .content

        unless result["contour_cross_check_passed"]
          return needs_human(
            "Content Type proposed as #{result['content_type']}, but the frame-contour " \
            "cross-check FAILED (predicted #{result['predicted_contour']}, observed " \
            "#{result['observed_contour']}). Per the rule, a contour mismatch means the " \
            "Content Type call is probably wrong.",
            { result: result, recommended_action: "reconsider" }
          )
        end

        needs_human("Confirm content type: #{result['content_type']}.",
                    { result: result, recommended_action: "confirm" })
      end
    end
  end
end
