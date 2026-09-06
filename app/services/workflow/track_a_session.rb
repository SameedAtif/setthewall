module Workflow
  class TrackASession
    ROOT = Rails.root.join("tmp", "track_a_sessions")

    def self.path_for(style_slug) = ROOT.join("#{style_slug}.json")

    def self.load(style_slug)
      path = path_for(style_slug)
      return { "style_slug" => style_slug, "decisions" => {}, "last_completed_step" => nil } unless path.exist?

      JSON.parse(path.read)
    end

    def self.save!(style_slug, session)
      ROOT.mkpath
      path_for(style_slug).write(JSON.pretty_generate(session))
    end

    # Called after every step that returns :ok or :awaiting_human — failed steps don't get
    # recorded, so a bad run doesn't poison the next attempt's defaults.
    def self.record_step_result!(style_slug, step_id, result_data)
      session = load(style_slug)
      session["decisions"][step_id] = result_data
      session["last_completed_step"] = step_id
      save!(style_slug, session)
    end

    def self.reset!(style_slug)
      path = path_for(style_slug)
      path.delete if path.exist?
    end
  end
end
