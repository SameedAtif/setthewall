module Schemas
  module TrackA
    # The typed, image-traced essence of a style's reference set. Produced by A1b (a vision pass
    # over A1's curated images) and consumed by C1 generation and ImageQa — so both grade and
    # generate against the same structured facts, instead of one prose blob.
    class ReferenceEssenceSchema < RubyLLM::Schema
      string :medium,
             description: "The physical medium/format the pieces are made as (e.g. flat printed " \
                          "poster, canvas print, painted canvas, framed print)"
      string :palette,
             description: "The colour range the pieces actually use — specific hues and their " \
                          "tonal range"
      string :palette_character,
             description: "A free-text description of the artwork's colour character — " \
                          "temperature, saturation, hue families, e.g. 'warm-neutral tonal range " \
                          "of bone, oatmeal and soft grey, no saturated hue'. Open-ended: do NOT " \
                          "pick from a fixed list."
      string :surface_treatment,
             description: "How the surface is worked (texture, marks, relief, finish) and how " \
                          "value and light behave across it"
      array :motif_vocabulary, of: :string,
            description: "The closed list of motifs/textures that recur. New pieces must use only "
      string :styling,
             description: "How the pieces are displayed (framing, wall, surrounding objects). " \
                          "Reported for completeness; NOT used for generation."
      array :outlier_indices, of: :integer,
            description: "1-based indices of reference images that are outliers for this style " \
                         "(off-medium, off-palette, or off-motif) and must not be used for generation"
      array :image_color_roles do
        object do
          integer :index, description: "1-based index of the reference image"
          string :color_role,
                 enum: %w[color_burst accent_highlighter unifier saturator line_only],
                 description: "The colour role embodied by the artwork in this image"
        end
      end
      array :field_evidence do
        object do
          string :field, enum: %w[medium palette surface_treatment motif_vocabulary styling]
          array :image_indices, of: :integer,
                description: "1-based indices of the reference images that support this field"
        end
      end
    end
  end
end
