module Steps
  module TrackB
    class RoomShape < Steps::Base
      step id: "B4", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::RoomShapeSchema)
                        .ask(prompt("b4_room_shape"), with: Pipeline::KB_ROOT.join(context.fetch(:scene_image)))
                        .content

        if result["borderline"]
          result["room_shape"] = rules("borderline_defaults").fetch("room_shape", "on_ambiguous")
        end

        ok({ room_shape: result["room_shape"], borderline: result["borderline"],
             reasoning: result["reasoning"] })
      end
    end
  end
end
