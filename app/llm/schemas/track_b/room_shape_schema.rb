module Schemas
  module TrackB
    class RoomShapeSchema < RubyLLM::Schema
      string :room_shape, enum: %w[narrow low_ceilinged small_closed_in none]
      boolean :borderline
      string :reasoning
    end
  end
end
