module Schemas
  module TrackA
    class MoodSchema < RubyLLM::Schema
      string :mood, enum: %w[calm_ordered bold_active mixed],
             description: "'mixed' means the scorecard did not resolve — do not force a call"

      array :marker_scores do
        object do
          string :marker, enum: %w[
            wall_art_color_relationship display_density arrangement_symmetry framing_weight
          ]
          string :lands_in, enum: %w[calm_ordered bold_active unclear]
          integer :supporting_image_count
          string :evidence, description: "What in the images supports this reading"
        end
      end

      integer :markers_supporting_chosen_mood,
              description: "How many of the 4 markers support the chosen value. Validation needs 2+."
      integer :clearly_supporting_images,
              description: "Images clearly supporting the chosen mood. Validation needs 3+."
    end
  end
end
