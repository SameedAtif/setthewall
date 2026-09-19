module Workflow
  # Applies a parsed reviewer decision (Llm::FeedbackInterpreter::Result) to its cell: validates the
  # disposition against DecisionRules, records the human gate closure, and advances or re-runs.
  class GateApplier
    # Raised when a decision would re-run a step with byte-identical context (DecisionRules
    # universal.identical_retry = refuse).
    class IdenticalRetry < StandardError; end

    def self.call(run_step:, interpretation:)
      new(run_step: run_step, interpretation: interpretation).call
    end

    def initialize(run_step:, interpretation:)
      @step  = run_step
      @interp = interpretation
      @run   = run_step.pipeline_run_record
    end

    def call
      verdict = @step.verdict.presence || "clean"
      Workflow::DecisionRules.validate_disposition!(
        step_id: @step.step_id, verdict: verdict, disposition: @interp.intent, reviewer_kind: "human",
        payload: { override_reason: override_reason, acceptance_note: @interp.notes }
      )

      apply_edits
      close_gate(verdict)
      dispatch
      @run
    end

    private

    def override_reason = @interp.reason.presence || @interp.notes

    def apply_edits
      return if @interp.edits.blank?

      @step.update!(output: (@step.output || {}).merge(@interp.edits))
    end

    def close_gate(verdict)
      gate = HumanGate.open.where(step_id: @step.step_id, piece_record_id: @run.piece_record_id)
                         .order(:opened_at).last
      return unless gate

      gate.update!(
        status: gate_status,
        verdict: verdict,
        reviewer_kind: "human",
        reviewer_decision: @interp.edits.to_json,
        reviewer_edits: @interp.edits,
        notes: @interp.notes,
        closed_at: Time.current
      )
    end

    def gate_status
      case @interp.intent
      when "approve" then "approved"
      when "edit"    then "edited"
      else "rejected"
      end
    end

    def dispatch
      case @interp.intent
      when "approve", "edit"
        # Mark the cell done and reveal the next one — but do not run it; the reviewer stays in
        # control and presses Run next / Run to next decision when ready.
        @step.update!(status: "done", disposition: @interp.intent, finished_at: Time.current)
        Workflow::NotebookBroadcaster.cell(@run, @step)
        Workflow::CellRunner.reveal_next(@run)
        Workflow::NotebookBroadcaster.header(@run)
      when "retry"
        refuse_identical_retry!
        @step.update!(disposition: "retry")
        queue_rerun(@step)
      when "rewind"
        @step.update!(disposition: "rewind")
        queue_rerun(rewind_target)
      when "abandon"
        @step.update!(disposition: "abandon")
        @run.update!(status: "abandoned", reviewed_at: Time.current)
        Workflow::NotebookBroadcaster.cell(@run, @step)
        Workflow::NotebookBroadcaster.header(@run)
      end
    end

    def rewind_target
      target = Workflow::DecisionRules.rewind_to(@step.step_id).first
      (target && @run.run_steps.find_by(step_id: target)) || @step
    end

    # Re-runs happen in a background job, never inline in the web request: a multi-minute research
    # step must not depend on the browser holding the connection open (an interrupted inline run
    # leaves the cell stuck "running" with nothing in the queue).
    def queue_rerun(step)
      step.update!(status: "queued")
      Workflow::NotebookBroadcaster.cell(@run, step)
      Workflow::NotebookBroadcaster.header(@run)
      ExecuteRunJob.perform_later(run_id: @run.id, mode: "rerun", run_step_id: step.id)
    end

    # A1's retry is refused only when the model explicitly reported an unreconcilable split
    # (dominant_mood == "mixed") and no narrowing override is present — a retry would reproduce it.
    def refuse_identical_retry!
      return unless @step.step_id == "A1"
      return if @step.context_override.present?
      return unless @step.mood_mixed?

      raise IdenticalRetry,
            "A1 reported an unreconcilable mood split — narrow it to one cluster before re-running."
    end
  end
end
