module Steps
  module TrackB
    class WallCondition < Steps::Base
      step id: "B1", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::WallConditionSchema)
                        .ask(prompt("b1_wall_condition"), with: context.fetch(:scene_image))
                        .content

        apply_borderline_default!(result, :wall_condition)

        ok({ wall_condition: result["wall_condition"], borderline: result["borderline"],
             reasoning: result["reasoning"] })
      end

      private

      # Even if the prompt tells the model what to do when borderline, we re-apply the rule in
      # code as a belt-and-braces guarantee — the borderline_defaults.yml file is the source of
      # truth for this behaviour, not the model.
      def apply_borderline_default!(result, axis_key)
        return unless result["borderline"]

        default = rules("borderline_defaults").fetch(axis_key.to_s, "on_ambiguous")
        return if default.nil?    # would only be true for B3, which doesn't call this method

        result[axis_key.to_s] = default
      end
    end
  end
end
