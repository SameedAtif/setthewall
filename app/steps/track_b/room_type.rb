module Steps
  module TrackB
    class RoomType < Steps::Base
      step id: "B3", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::RoomTypeSchema)
                        .ask(prompt("b3_room_type"), with: context.fetch(:scene_image))
                        .content

        if result["room_type"] == "ambiguous"
          # This is enforced from the rule file explicitly — the escalate flag is the machine-
          # readable signal that B3 has no safe default and MUST NOT fall back to guessing.
          rule = rules("borderline_defaults").fetch("room_type")
          return needs_human(
            "B3 came back ambiguous (#{result['ambiguity_reason']}). Per " \
            "borderline_defaults.yml, this axis has no safe default: #{rule['reasoning']} " \
            "Classify the room type as seated_room, hallway, or no_furniture_wall.",
            { llm_result: result, escalation_reason: rule["escalation_reason"] }
          )
        end

        ok({ room_type: result["room_type"], reasoning: result["reasoning"] })
      end
    end
  end
end
