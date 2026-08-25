module Schemas
  module TrackA
    class ContentTypeSchema < RubyLLM::Schema
      string :content_type,
             enum: %w[detailed_representational minimalist_modern portrait_still_life]
      string :predicted_contour, enum: %w[inward_sloping_beveled flush_level_plane outward_sloping]
      string :observed_contour,
             enum: %w[inward_sloping_beveled flush_level_plane outward_sloping mixed unclear]
      boolean :contour_cross_check_passed
      string :reasoning
    end
  end
end
