module Workflow
  # Re-runs a cell (and invalidates everything after it) after a reviewer decision. Downstream cells
  # are marked stale but left visible; because stale cells are excluded from the mirrored
  # step_results, they stop contributing context until re-run manually.
  class CellRerunner
    def self.call(run_step:) = new(run_step: run_step).call

    def initialize(run_step:)
      @step = run_step
      @run  = run_step.pipeline_run_record
    end

    def call
      mark_downstream_stale
      reset_cell
      @run.mirror_step_results!
      Workflow::CellRunner.run_next(@run)
    end

    private

    def mark_downstream_stale
      @run.run_steps.where("position > ?", @step.position).each do |step|
        step.update!(status: "stale")
        Workflow::NotebookBroadcaster.cell(@run, step)
      end
    end

    def reset_cell
      @step.update!(status: "pending", output: {}, message: nil, verdict: nil,
                    disposition: nil, escalation: {}, finished_at: nil)
    end
  end
end
