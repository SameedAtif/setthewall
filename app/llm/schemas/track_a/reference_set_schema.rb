module Schemas
  module TrackA
    class ReferenceSetSchema < RubyLLM::Schema
      array :images do
        object do
          string :url, description: "Direct URL of the image file itself (from the search results' " \
                                    "'images' list), not the page the image appears on"
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
      array :mood_clusters_found do
        object do
          string :label, description: "Short name for this mood camp (e.g. 'calm botanical', " \
                                      "'bold celestial')"
          array :image_indices, of: :integer,
                description: "1-based indices of the images that belong to this camp"
        end
      end
      array :shared_qualities, of: :string,
            description: "The qualities the mood camps share — palette, material, surface " \
                         "treatment, level of abstraction, styling. Non-empty when the camps " \
                         "reconcile into one mood."
      string :dominant_mood, enum: %w[calm_ordered bold_active mixed],
             description: "The single mood to move forward with after reconciling the camps. Use " \
                          "'mixed' ONLY when the camps genuinely cannot be reconciled — stylistic " \
                          "variation within one mood is not a reason to return 'mixed'."
      string :reconciliation_note,
             description: "How the camps reconcile into dominant_mood, or why they cannot."
    end
  end
end
