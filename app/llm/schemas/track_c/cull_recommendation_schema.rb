module Schemas
  module TrackC
    # A reasoned cull recommendation the human reviews at the C2 gate.
    class CullRecommendationSchema < RubyLLM::Schema
      array :ranking do
        object do
          integer :index, description: "1-based candidate index"
          string :verdict, enum: %w[keep borderline drop],
                 description: "Whether to carry this candidate forward, keep it borderline, or drop it"
          string :reason, description: "One sentence explaining the verdict"
        end
      end
      array :recommended_finalists, of: :integer,
            description: "1-based indices of the candidates to keep as finalists (at most the cull cap)"
      integer :recommended_chosen,
              description: "1-based index of the single best candidate to choose"
      string :reasoning,
             description: "Overall reasoning for the cull, referencing the style and the finalist choice"
    end
  end
end
