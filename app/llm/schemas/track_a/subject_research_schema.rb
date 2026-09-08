module Schemas
  module TrackA
    class SubjectResearchSchema < RubyLLM::Schema
      integer :shops_sampled,
              description: "Number of independent shops actually sampled"
      array :subjects do
        object do
          string :subject,
                 description: "A concrete subject category, e.g. 'cottage or dwelling', 'moth'"
          integer :recurs_across_shops,
                  description: "How many independent shops this subject recurs across"
        end
      end
    end
  end
end
