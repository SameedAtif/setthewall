module Schemas
  module TrackB
    # Only covers step 1 of B6. Steps 2 and 3 are decided outside the LLM call.
    class ColorRoleObservationSchema < RubyLLM::Schema
      string :candidate_role,
             enum: %w[color_burst accent_highlighter unifier saturator]
      string :observed_color_state,
             description: "The specific colour state observed — used later for the B1/B2 cross-check"
      string :reasoning
    end
  end
end
