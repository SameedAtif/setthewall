module Schemas
  module TrackB
    class WallConditionSchema < RubyLLM::Schema
      string :wall_condition, enum: %w[neutral busy]
      boolean :borderline, description: "True if the safe-fail default was invoked"
      string :reasoning
    end
  end
end
