module Schemas
  module TrackA
    class StyleIdeationSchema < RubyLLM::Schema
      array :candidates do
        object do
          string :name, description: "A specific, nameable style — not a vague mood word"
          string :trend_signal, description: "One-line explanation of why this is surfacing now"
          integer :independent_source_count,
                  description: "How many genuinely independent sources support this candidate. Must be >= 2 to be included."
          array :sources do
            object do
              string :source_name
              boolean :promotional_language_detected
            end
          end
          string :competition_read, enum: %w[low medium high unknown]
        end
      end
      string :survey_notes,
             description: "Anything about the survey itself worth flagging — sparse data, conflicting signals, etc."
      string :recommended_focus,
             description: "The single best candidate name to pursue — exactly one, the one with " \
                          "the strongest independent support. Never a list, never joined by 'and'."
    end
  end
end
