module Workflow
  class PreflightCheck
    WATCHED_PATHS = %w[knowledge_base/].freeze

    Result = Struct.new(:kb_version, :dirty, keyword_init: true)

    # Returns a Result. Raises unless allow_dirty is true and the tree is dirty.
    #
    #   allow_dirty: false (default) — production run. Refuses on any uncommitted change.
    #   allow_dirty: true            — local iteration. Stamps "dirty:<sha>" so the run is
    #                                  identifiable as untrustworthy in later analysis.
    def self.call!(allow_dirty: false)
      status = `git status --porcelain #{WATCHED_PATHS.join(" ")}`.strip
      sha    = `git rev-parse HEAD`.strip

      raise DirtyKnowledgeBaseError, "git not available or not a repo" if sha.empty?

      if status.empty?
        Result.new(kb_version: sha, dirty: false)
      elsif allow_dirty
        Result.new(kb_version: "dirty:#{sha}", dirty: true)
      else
        raise DirtyKnowledgeBaseError, <<~MSG
          Uncommitted changes in the knowledge base. Commit before running:

          #{status}

          To run anyway for local iteration, pass allow_dirty: true. Runs made this way are
          stamped "dirty:<sha>" and should not be used for performance analysis.
        MSG
      end
    end
  end
end
