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

    # Walk the run's CURRENT effective order (not just the cells that already exist), so a step
    # introduced into the order after the run was created (e.g. A1b) is materialized and staled too.
    # Only steps up to the furthest already-materialized cell are created — the notebook must not
    # suddenly fill with every future step.
    def mark_downstream_stale
      order = Workflow::RunSequencer.effective_order(@run)
      index = order.index(@step.step_id)
      return if index.nil?

      existing = @run.run_steps.index_by(&:step_id)
      furthest = order.each_index.select { |i| i > index && existing.key?(order[i]) }.max
      return if furthest.nil?

      order[(index + 1)..furthest].each do |step_id|
        cell = existing[step_id] || ensure_cell(step_id, order.index(step_id))
        cell.update!(status: "stale") unless cell.stale?
        Workflow::NotebookBroadcaster.cell(@run, cell)
      end

      resync_positions(order)
    end

    def ensure_cell(step_id, position)
      RunStep.find_or_create_by!(pipeline_run_record_id: @run.id, step_id: step_id) do |step|
        step.position = position
      end
    end

    # Positions were assigned when each cell was materialized; re-anchor them to the run's current
    # effective order so a step introduced later (e.g. A1b) sorts correctly in the notebook.
    def resync_positions(order)
      @run.run_steps.find_each do |cell|
        position = order.index(cell.step_id)
        cell.update_columns(position: position) if position && cell.position != position
      end
    end

    def reset_cell
      @step.update!(status: "pending", output: {}, message: nil, verdict: nil,
                    disposition: nil, escalation: {}, finished_at: nil)
    end
  end
end
