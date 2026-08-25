module Schemas
  module TrackB
    class SpaceMathSchema < RubyLLM::Schema
      string :space_math, enum: %w[single set split_wall nook surface]
      string :reasoning,
             description: "Include the proportions you used to arrive at this classification"
    end
  end
end
