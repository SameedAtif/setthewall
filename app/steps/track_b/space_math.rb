module Steps
  module TrackB
    class SpaceMath < Steps::Base
      step id: "B5", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::SpaceMathSchema)
                        .ask(prompt("b5_space_math"), with: Pipeline::KB_ROOT.join(context.fetch(:scene_image)))
                        .content

        ok({ space_math: result["space_math"], reasoning: result["reasoning"] })
      end
    end
  end
end
