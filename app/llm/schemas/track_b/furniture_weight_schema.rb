module Schemas
  module TrackB
    class FurnitureWeightSchema < RubyLLM::Schema
      string :furniture_weight, enum: %w[light dark]
      boolean :borderline
      string :reasoning
    end
  end
end
