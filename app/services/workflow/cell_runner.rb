module Workflow
  # Drives a run's notebook one cell at a time. Uses the shared Workflow::StepExecution for
  # behavior identical to the Conductor, and persists each step as a RunStep (which mirrors back
  # into PipelineRunRecord#step_results).
  #
  # Cells are materialized progressively: a run starts with only its first cell, and each completed
  # cell reveals the next. Every cell records timestamped logs while it runs.
  #
  #   prepare         — materialize the first cell of a new run
  #   queue_next      — mark the next runnable cell "queued" (immediate UI feedback)
  #   run_next        — execute the next runnable cell
  #   run_until_gate  — advance until a cell pauses (gate/failure/rewind)
  #   run_all         — execute every remaining cell (auto-closing gates like the Conductor)
  class CellRunner
    def self.prepare(run) = new(run).prepare
    def self.queue_next(run) = new(run).queue_next
    def self.reveal_next(run) = new(run).reveal_next
    def self.run_next(run) = new(run).run_next
    def self.run_until_gate(run) = new(run).run_until_gate
    def self.run_all(run) = new(run).run_all

    def initialize(run) = @run = run

    # Materialize only the first cell, so the notebook grows as the run progresses. Steps already
    # satisfied by a committed spec (style and/or scene) are marked `skipped` up front.
    def prepare
      mark_prelocked_steps_skipped
      step_id = Workflow::RunSequencer.next_runnable(@run)
      ensure_cell(step_id) if step_id
      @run
    end

    # Immediate feedback on click: flag the next cell as queued and push it to the browser before
    # the job is picked up.
    def queue_next
      step_id = Workflow::RunSequencer.next_runnable(@run)
      return nil if step_id.nil?

      step = ensure_cell(step_id)
      step.update!(status: "queued")
      @run.update!(status: "running") unless %w[abandoned committed approved].include?(@run.status)
      Workflow::NotebookBroadcaster.cell(@run, step)
      Workflow::NotebookBroadcaster.header(@run)
      step
    end

    # Reveal the next runnable cell as pending (without running it). Used after a human decision so
    # the notebook grows one cell at a time under the reviewer's control.
    def reveal_next
      step_id = Workflow::RunSequencer.next_runnable(@run)
      return nil if step_id.nil?

      step = ensure_cell(step_id)
      Workflow::NotebookBroadcaster.append_cell(@run, step) if step.previously_new_record?
      @run
    end

    def run_next
      step_id = Workflow::RunSequencer.next_runnable(@run)
      return @run if step_id.nil?

      execute_cell(ensure_cell(step_id))
      finalize_if_complete
      @run
    end

    def run_until_gate = run(stop_on_pause: true)
    def run_all = run(stop_on_pause: false)

    private

    def run(stop_on_pause:)
      executed = Set.new
      loop do
        step_id = next_unexecuted(executed)
        break if step_id.nil?

        step = execute_cell(ensure_cell(step_id))
        executed << step_id
        break if stop_on_pause && paused?(step)
      end

      finalize_if_complete
      @run
    end

    def next_unexecuted(executed)
      Workflow::RunSequencer.effective_order(@run).find do |step_id|
        next false if executed.include?(step_id)

        !@run.run_steps.where(step_id: step_id, status: %w[done skipped]).exists?
      end
    end

    def ensure_cell(step_id)
      # Query by attributes rather than through the association: the RunStep mirror callback reloads
      # the run's run_steps mid-save, which corrupts a loaded association target into duplicates.
      RunStep.find_or_create_by!(pipeline_run_record_id: @run.id, step_id: step_id) do |step|
        step.position = position_for(step_id)
      end
    end

    # When a run is created against a spec that is already committed, its style (or scene) steps
    # are shown as satisfied rather than re-run. Recorded as `skipped` cells so the sequencer treats
    # them as complete.
    def mark_prelocked_steps_skipped
      return if @run.scope.to_s == "piece"

      if Workflow::RunSequencer.locked_style?(@run)
        Workflow::RunSequencer::STYLE_ORDER.each { |id| mark_skipped(id) }
      elsif @run.scope.to_s != "style" && Workflow::RunSequencer.locked_scene?(@run)
        Workflow::RunSequencer::SCENE_STEPS.each { |id| mark_skipped(id) }
      end
    end

    def mark_skipped(step_id)
      cell = ensure_cell(step_id)
      cell.update!(status: "skipped") unless cell.skipped?
    end

    def position_for(step_id)
      Workflow::RunSequencer.effective_order(@run).index(step_id) || @run.run_steps.count
    end

    def execute_cell(step)
      step.update!(status: "running", started_at: Time.current, finished_at: nil)
      log(step, "Started #{step.step_id}")
      Workflow::NotebookBroadcaster.cell(@run, step)
      Workflow::NotebookBroadcaster.header(@run)

      outcome = Workflow::StepLogging.with_logger(step_logger(step)) do
        Workflow::StepExecution.call(run: @run, step_id: step.step_id,
                                     piece: @run.piece_record, log: step_logger(step))
      end
      persist(step, outcome)
      step.reload
    rescue StandardError => e
      log(step, "#{e.class}: #{e.message}", level: "error")
      step.update!(status: "failed", message: e.message, finished_at: Time.current)
      Workflow::NotebookBroadcaster.cell(@run, step)
      step
    end

    def persist(step, outcome)
      status = cell_status(outcome)
      step.update!(
        status: status,
        output: (outcome.data || {}).deep_stringify_keys,
        message: outcome.message,
        verdict: outcome.verdict,
        disposition: outcome.disposition,
        reviewer_kind: "agent",
        finished_at: Time.current,
        context_override: {}
      )
      log(step, "Finished: #{status}")
      step.update!(summary: Llm::CellSummarizer.call(run_step: step))
      if status == "awaiting_human"
        step.update!(decision_options: Llm::DecisionOptions.call(run_step: step))
        open_gate(step, outcome)
      end
      @run.update!(status: "running")
      Workflow::NotebookBroadcaster.cell(@run, step)
      materialize_next
      Workflow::NotebookBroadcaster.header(@run)
    end

    def materialize_next
      step_id = Workflow::RunSequencer.next_runnable(@run)
      return if step_id.nil?

      step = ensure_cell(step_id)
      Workflow::NotebookBroadcaster.append_cell(@run, step) if step.previously_new_record?
    end

    def cell_status(outcome)
      return "failed" if outcome.status == :failed
      return "awaiting_human" if pause?(outcome)

      "done"
    end

    def pause?(outcome)
      outcome.paused? || outcome.status == :awaiting_human || outcome.disposition == "rewind"
    end

    def paused?(step)
      %w[awaiting_human failed].include?(step.status) || step.disposition == "rewind"
    end

    def open_gate(step, outcome)
      already_open = HumanGate.open.where(step_id: step.step_id,
                                          piece_record_id: @run.piece_record_id).exists?
      return if already_open

      HumanGate.create!(
        piece_record: @run.piece_record,
        step_id: step.step_id,
        gate_kind: step.step_id.parameterize.underscore,
        status: "open",
        agent_proposal: (outcome.data || {}).to_json,
        context_snapshot: {},
        opened_at: Time.current,
        notes: outcome.message
      )
    end

    def step_logger(step)
      ->(message, level: :info) { log(step, message, level: level) }
    end

    def log(step, message, level: "info")
      entry = step.log!(message, level: level)
      Workflow::NotebookBroadcaster.log(@run, step, entry)
    end

    # A run is ready for dossier review once every step in its effective order has been executed
    # at least once (none left pending/queued/running).
    def finalize_if_complete
      order = Workflow::RunSequencer.effective_order(@run)
      return if order.any? { |id| !@run.run_steps.exists?(step_id: id) }
      return if @run.run_steps.where(step_id: order, status: %w[pending queued running awaiting_human]).exists?

      @run.update!(status: "awaiting_dossier_review", dossier_ready_at: Time.current)
      Workflow::NotebookBroadcaster.header(@run)
      Workflow::DossierRefresher.call(run: @run)
    end
  end
end
