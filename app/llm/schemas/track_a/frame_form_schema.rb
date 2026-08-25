module Schemas
  module TrackA
    class FrameFormSchema < RubyLLM::Schema
      string :frame_form, enum: %w[angular rounded]
      string :consistency, enum: %w[consistent mixed]
      boolean :tiebreaker_used, description: "True if mood was used to resolve a mixed reading"
      string :reasoning
    end
  end
end
