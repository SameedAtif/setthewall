module Workflow
  class SpeculativeWriteError < StandardError; end

  # A run is `speculative` (all persistent writes redirected to tmp/) or `committed`. The default
  # is `committed` — the existing human-gated flows (rake tasks, jobs, the review UI) run committed.
  # The conductor explicitly wraps a run in `speculative` via `.with`, and CommitRunJob wraps the
  # replay in `committed`. (Module 09 §1.1 prefers a speculative default; the committed default is
  # the integration choice so the pre-existing flows keep working until the conductor is the only
  # entry point.)
  class RunMode
    MODES = %w[speculative committed].freeze

    def self.current = Thread.current[:pipeline_run_mode] || "committed"
    def self.speculative? = current == "speculative"

    def self.with(mode, run_id:)
      raise ArgumentError, "bad mode #{mode}" unless MODES.include?(mode)

      prev, prev_id = Thread.current[:pipeline_run_mode], Thread.current[:pipeline_run_id]
      Thread.current[:pipeline_run_mode], Thread.current[:pipeline_run_id] = mode, run_id
      yield
    ensure
      Thread.current[:pipeline_run_mode], Thread.current[:pipeline_run_id] = prev, prev_id
    end

    # Every writer asks for its root through here. Nothing hardcodes KB_ROOT any more.
    def self.write_root
      speculative? ? staging_root : Pipeline::KB_ROOT
    end

    def self.staging_root
      id = Thread.current[:pipeline_run_id] or raise SpeculativeWriteError, "no run_id in scope"
      Rails.root.join("tmp", "runs", id, "staging").tap(&:mkpath)
    end

    # Called by anything that must never run speculatively (Etsy publish, git commit, KB applier).
    def self.require_committed!(what)
      return unless speculative?

      raise SpeculativeWriteError, "#{what} attempted during a speculative run. Approve the dossier first."
    end
  end
end
