module Schemas
  module Qa
    class ImageConformanceSchema < RubyLLM::Schema
      array :per_image do
        object do
          integer :index, description: "1-based index of the candidate image"
          array :axis_mismatches, of: :string,
                description: "Which locked axes this candidate fails to read as (empty if it conforms)"
        end
      end
      array :constraint_violations, of: :string,
            description: "Negative-prompt constraint violations found in the batch"
    end
  end
end
