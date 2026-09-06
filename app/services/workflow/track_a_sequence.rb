module Workflow
  class TrackASequence
    ORDER = %w[A_IDEATE A0 A1 A2 A3 A4 A5].freeze

    # For each step, where its context values come from:
    #   { key => [:session, "STEP_ID", "field_in_that_step's_result_data"] }  — auto-filled
    #   { key => :fresh }                                                     — must be passed this call
    SOURCES = {
      "A_IDEATE" => {},   # everything optional/fresh — see step class
      "A0" => {
        style_name: :fresh,      # first call in a session — nothing to carry forward from yet
        style_slug: :fresh
      },
      "A1" => {
        style_name: [:session, "A0", "style_name_used"]   # see §3.1 note below
      },
      "A2" => {
        reference_images: [:session, "A1", "curated_images"]
      },
      "A3" => {
        reference_images: [:session, "A2", "reference_images"]
      },
      "A4" => {
        reference_images: [:session, "A3", "reference_images"],
        mood: [:session, "A2", "mood"]
      },
      "A5" => {
        style_slug: :fresh,   # session key itself, always explicit for safety
        style_name: [:session, "A0", "style_name_used"],
        mood: [:session, "A2", "mood"],
        content_type: [:session, "A3", "content_type"],
        frame_form: [:session, "A4", "frame_form"],
        confirmed: :fresh     # NEVER auto-filled — see §1.1
      }
    }.freeze

    def self.next_step_for(session)
      last = session["last_completed_step"]
      return ORDER.first if last.nil?

      idx = ORDER.index(last)
      raise ArgumentError, "Unknown last_completed_step=#{last}" if idx.nil?
      ORDER[idx + 1]
    end

    # Merges session-derived defaults with fresh_context (fresh_context always wins on conflict —
    # an explicit override this call beats whatever the session remembers).
    def self.build_context(step_id, session, fresh_context)
      mapping = SOURCES.fetch(step_id, {})
      derived = mapping.each_with_object({}) do |(key, source), ctx|
        next if source == :fresh   # caller must supply this; skip auto-fill
        _, from_step, field = source
        value = session.dig("decisions", from_step, field.to_s)
        ctx[key] = value unless value.nil?
      end
      derived.merge(fresh_context)
    end

    # Which keys THIS call still needs that neither the session nor fresh_context supplied —
    # used to give a clear error instead of the step class failing on a missing context key.
    def self.missing_required(step_id, built_context)
      mapping = SOURCES.fetch(step_id, {})
      mapping.keys.select { |k| built_context[k].nil? }
    end
  end
end
