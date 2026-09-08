module Schemas
  module TrackA
    class StyleValidationSchema < RubyLLM::Schema
      string :breadth_assessment,
             enum: %w[single_coherent_style fragments_into_substyles],
             description: "Does the candidate resolve to ONE producible style, or split into " \
                          "multiple genuinely different sub-styles (subject, price tier, or " \
                          "production difficulty)? Must be answered before findings are trusted."
      array :findings do
        object do
          string :theme,                 description: "Style or theme identified"
          integer :independent_shops,    description: "Number of DIFFERENT shops it recurs across"
          string :competition_density,   description: "Approximate listing count or density band"
          string :cross_check_platform,  description: "Platform used for the independent cross-check"
          boolean :cross_check_confirmed
          string :demand_to_competition_verdict
        end
      end
      array :cross_check_attempts, of: :string,
            description: "Every route tried to get Google Trends/Pinterest data, including " \
                         "failed attempts and why they failed. Must not be empty — a bare " \
                         "'not retrievable' with no attempt shown fails validation."
      string :single_recommended_focus,
             description: "Exactly ONE theme name from findings — never a list, never joined " \
                          "by 'and'. If breadth_assessment is fragments_into_substyles, this is " \
                          "your pick of the single best sub-theme, not an average across them."
      object :production_model do
        string :fulfillment_type, enum: %w[digital physical],
               description: "How the winning sub-theme is actually sold — digital download or " \
                            "physical printed/shipped product."
        integer :piece_count, description: "1 for a single-piece style; >1 for multi-piece sets"
        string :price_tier_usd, description: "Observed price band, e.g. '40-57'"
      end
      string :recommendation_reasoning,
             description: "Why this one specifically beats the other candidates found."
      string :methodology_caveats, description: "Any limits on how reliable these findings are"
    end
  end
end
