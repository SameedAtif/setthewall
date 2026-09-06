module Steps
  module TrackB
    class FurnitureWeight < Steps::Base
      step id: "B2", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::FurnitureWeightSchema)
                        .ask(prompt("b2_furniture_weight"), with: Pipeline::KB_ROOT.join(context.fetch(:scene_image)))
                        .content

        if result["borderline"]
          result["furniture_weight"] = rules("borderline_defaults")
                                       .fetch("furniture_weight", "on_ambiguous")
        end

        ok({ furniture_weight: result["furniture_weight"], borderline: result["borderline"],
             reasoning: result["reasoning"] })
      end
    end
  end
end
