module Schemas
  module TrackB
    class RoomTypeSchema < RubyLLM::Schema
      string :room_type,
             enum: %w[seated_room hallway no_furniture_wall ambiguous],
             description: "'ambiguous' triggers a human-required escalation — there is no safe default here"
      string :reasoning
      string :ambiguity_reason, required: false,
             description: "Required if room_type is 'ambiguous'"
    end
  end
end
