module Schemas
  module TrackA
    class StyleValidationSchema < RubyLLM::Schema
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
      string :recommended_style_focus
      string :methodology_caveats, description: "Any limits on how reliable these findings are"
    end
  end
end
