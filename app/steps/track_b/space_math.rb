module Steps
  module TrackB
    class SpaceMath < Steps::Base
      step id: "B5", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = Pipeline::Json.normalize(
          RubyLLM.chat(model: Pipeline::VISION_MODEL)
                 .with_schema(Schemas::TrackB::SpaceMathSchema)
                 .ask(prompt("b5_space_math"), with: Pipeline::KB_ROOT.join(context.fetch(:scene_image)))
                 .content
        )

        space_math = result["space_math"]

        if space_math == "single" && production_piece_count > 1
          return needs_human(
            "A0 selected a multi-piece production model (piece_count=#{production_piece_count}) " \
            "but this scene's geometry only supports a single piece. Escalating rather than " \
            "silently choosing one.",
            { space_math: space_math, piece_count: production_piece_count }
          )
        end

        ok({ space_math: space_math, reasoning: result["reasoning"] })
      end

      private

      def production_piece_count
        spec = KnowledgeBase::StyleSpec.load(context.fetch(:style_slug))
        spec.production_model["piece_count"].to_i
      rescue StandardError
        1
      end
    end
  end
end
