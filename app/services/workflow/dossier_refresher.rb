module Workflow
  # Rebuilds a run's dossier from its current cell state. Failures are logged, never raised — a
  # stale dossier is recoverable, a crashed run is not.
  class DossierRefresher
    def self.call(run:) = new(run).call

    def initialize(run) = @run = run

    def call
      @run.update!(dossier_markdown: Dossier::Builder.call(run: @run),
                   dossier_ready_at: Time.current)
      Workflow::NotebookBroadcaster.dossier(@run)
      @run
    rescue StandardError => e
      Rails.logger.warn("[DossierRefresher] #{@run.run_id}: #{e.class}: #{e.message}")
      @run
    end
  end
end
