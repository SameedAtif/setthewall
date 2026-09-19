module Schemas
  module Qa
    class ImageConformanceSchema < RubyLLM::Schema
      array :per_image do
        object do
          integer :index, description: "1-based index of the candidate image"
          array :axis_mismatches, of: :string,
                description: "Which locked axes this candidate fails to read as (empty if it conforms)"
          boolean :subject_conforms,
                  description: "Whether the candidate depicts the subject it was specified to depict"
          integer :max_reference_similarity,
                  description: "0-100: similarity to the SINGLE most similar reference image " \
                               "(the anchoring detector — a high value means it is close to a copy)"
          boolean :palette_conforms,
                  description: "Whether the palette matches the reference essence"
          boolean :surface_conforms,
                  description: "Whether the surface treatment matches the reference essence"
          boolean :motif_conforms,
                  description: "Whether the motifs stay inside the reference motif vocabulary"
          object :descriptors do
            string :transition_position,
                   description: "Where the light/dark transition sits (e.g. top-left, centre, " \
                                "bottom-right, none)"
            string :transition_orientation,
                   description: "Direction of the transition (diagonal, vertical, horizontal, " \
                                "radial, none)"
            string :seam_presence,
                   description: "Whether/where an accent line or seam is present (none, trace, strong)"
            string :motif_region_shape,
                   description: "Shape of the dominant motif region"
          end
        end
      end
      array :constraint_violations, of: :string,
            description: "Negative-prompt constraint violations found in the batch"
    end
  end
end
