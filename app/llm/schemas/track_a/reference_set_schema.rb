module Schemas
  module TrackA
    class ReferenceSetSchema < RubyLLM::Schema
      array :images do
        object do
          string :url
          string :source_type, enum: %w[retailer design_publication pinterest_attributed]
          string :source_name
          array :attributing_sources, of: :string,
                description: "The independent sources that attribute this to the style. Must be 2+."
          string :shot_type, enum: %w[in_situ closeup]
        end
      end
      integer :closeup_count
      integer :total_count
      array :sources_used, of: :string
    end
  end
end
