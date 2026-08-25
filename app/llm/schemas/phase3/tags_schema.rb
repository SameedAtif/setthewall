module Schemas
  module Phase3
    class TagsSchema < RubyLLM::Schema
      array :tags,
            description: "Exactly 13 tags. Each tag labelled with the angle it serves." do
        object do
          string :tag
          string :angle, enum: %w[style_descriptor room_or_space_use gift_or_occasion alternate_use]
          string :breadth, enum: %w[broad specific_long_tail]
        end
      end
      integer :distinct_angles_covered,
              description: "How many of the 4 angles are represented across the 13 tags. Validation requires >= 3."
      array :missing_angles, of: :string,
            description: "Angles you couldn't populate with a non-forced tag."
    end
  end
end
