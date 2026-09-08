module Schemas
  module TrackC
    class PromptSynthesisSchema < RubyLLM::Schema
      string :image_generation_prompt,
             description: "The final constructed prompt to send to the image-generation API"
      array :axis_contributions,
            description: "Which phrase came from which axis — for auditability" do
        object do
          string :axis,
                 enum: %w[content_type mood color_role frame_form room_shape subject narrative]
          string :phrase_added
        end
      end
      string :negative_prompt,
             description: "The negative-prompt clause: no watermark, no signature, etc."
    end
  end
end
