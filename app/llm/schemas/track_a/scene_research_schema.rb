module Schemas
  module TrackA
    class SceneResearchSchema < RubyLLM::Schema
      integer :shops_sampled,
              description: "Number of independent shops actually sampled"
      array :scene_patterns do
        object do
          string :pattern_id, description: "A stable id for this recurring scene pattern"
          string :narrative_structure,
                 description: "The whole-scene narrative shape, abstracted (no specific subject/setting)"
          string :light_logic,
                 description: "How the brightest/warmest point relates to the rest of the frame"
          string :temporal_quality,
                 description: "Implied 'just before/after' vs static posed scene"
          integer :recurs_across_shops,
                  description: "How many independent shops this pattern recurs across"
        end
      end
    end
  end
end
