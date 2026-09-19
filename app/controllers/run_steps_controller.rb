class RunStepsController < ApplicationController
  layout "notebook"

  rescue_from Workflow::GateApplier::IdenticalRetry, with: :refuse_identical_retry

  def run
    step = RunStep.find(params[:id])
    step.update!(status: "queued")
    Workflow::NotebookBroadcaster.cell(step.pipeline_run_record, step)
    ExecuteRunJob.perform_later(run_id: step.pipeline_run_record_id, mode: "rerun",
                                run_step_id: step.id)
    head :accepted
  end

  # Interpret the reviewer's prose and render the confirmation preview inside the cell's frame.
  def interpret
    step = RunStep.find(params[:id])
    result = Llm::FeedbackInterpreter.call(run_step: step, body: params[:feedback])
    feedback = step.step_feedbacks.create!(
      role: "human", body: params[:feedback], applied: false,
      parsed: { "intent" => result.intent, "notes" => result.notes,
                "reason" => result.reason, "edits" => result.edits }
    )
    render partial: "run_steps/preview",
           locals: { run: step.pipeline_run_record, step: step, feedback: feedback }
  rescue Llm::FeedbackInterpreter::IllegalIntent => e
    render partial: "run_steps/feedback_composer",
           locals: { run: step.pipeline_run_record, step: step, error: e.message },
           status: :unprocessable_content
  end

  # Apply a previously interpreted decision.
  def decision
    step = RunStep.find(params[:id])
    feedback = step.step_feedbacks.find(params[:feedback_id])
    Workflow::GateApplier.call(run_step: step, interpretation: interpretation_for(feedback))
    feedback.update!(applied: true)
    redirect_to run_path(step.pipeline_run_record, anchor: focus_anchor(step.pipeline_run_record))
  end

  # Apply a pre-generated decision option directly (no interpretation needed — it is already
  # structured).
  def decide
    step = RunStep.find(params[:id])
    option = Array(decision_options_for(step))[params[:option_index].to_i]
    if option.blank?
      return redirect_to run_path(step.pipeline_run_record), alert: "Choose one of the options."
    end

    Workflow::GateApplier.call(run_step: step, interpretation: option_interpretation(option))
    redirect_to run_path(step.pipeline_run_record, anchor: focus_anchor(step.pipeline_run_record))
  end

  # Resolve B6's content-type override: confirm the documented default (line_only) or keep the
  # observed role with a catalog-strategy reason. Stored as a context override, then B6 re-runs.
  COLOR_ROLES = %w[line_only color_burst accent_highlighter unifier saturator].freeze

  def color_role
    step = RunStep.find(params[:id])
    choice = params[:color_role].to_s

    return rerun_color_role(step, choice) if COLOR_ROLES.include?(choice)

    case choice
    when "rewind", "abandon"
      Workflow::GateApplier.call(run_step: step, interpretation: disposition_interpretation(choice))
      redirect_to run_path(step.pipeline_run_record, anchor: focus_anchor(step.pipeline_run_record))
    else
      redirect_to run_path(step.pipeline_run_record), alert: "Choose a color role."
    end
  end

  # Record a plain reviewer note without changing the run's state.
  def note
    step = RunStep.find(params[:id])
    step.step_feedbacks.create!(role: "human", body: params[:note], applied: false, parsed: {})
    redirect_to run_path(step.pipeline_run_record), notice: "Note added."
  end

  # Narrow a step's scope and re-run it (currently A1's mood clusters). The chosen scope is stored
  # as a context override consumed by Context::Assembler on the next run, then cleared.
  def narrow
    step = RunStep.find(params[:id])
    style_name = params[:custom_style_name].presence || params[:style_name].presence
    if style_name.blank?
      return redirect_to run_path(step.pipeline_run_record),
                         alert: "Choose a mood cluster (or describe one) to narrow to."
    end

    step.update!(context_override: { "style_name" => style_name }, status: "queued")
    Workflow::NotebookBroadcaster.cell(step.pipeline_run_record, step)
    ExecuteRunJob.perform_later(run_id: step.pipeline_run_record_id, mode: "rerun",
                                run_step_id: step.id)
    redirect_to run_path(step.pipeline_run_record),
                notice: "Re-running #{step.step_id} scoped to \"#{style_name}\"."
  end

  # Discard a preview and return to the composer.
  def composer
    step = RunStep.find(params[:id])
    render partial: "run_steps/feedback_composer",
           locals: { run: step.pipeline_run_record, step: step }
  end

  private

  def rerun_color_role(step, role)
    override = { "color_role_override" => role }
    # Confirming the role the run proposed needs no justification; choosing anything else does.
    observed = step.output["observation_candidate"].presence || step.output["proposed_role"].presence
    if role != observed
      reason = params[:reason].to_s.strip
      if reason.blank?
        return redirect_to run_path(step.pipeline_run_record),
                           alert: "Provide a catalog-strategy reason to choose #{role}."
      end
      override["catalog_strategy_override"] = reason
    end

    step.update!(context_override: override, status: "queued")
    Workflow::NotebookBroadcaster.cell(step.pipeline_run_record, step)
    ExecuteRunJob.perform_later(run_id: step.pipeline_run_record_id, mode: "rerun",
                                run_step_id: step.id)
    redirect_to run_path(step.pipeline_run_record), notice: "Re-running B6 with color role \"#{role}\"."
  end

  def disposition_interpretation(intent)
    Llm::FeedbackInterpreter::Result.new(intent: intent, notes: nil, edits: {}, reason: nil, raw: {})
  end

  def refuse_identical_retry(error)
    step = RunStep.find(params[:id])
    redirect_to run_path(step.pipeline_run_record), alert: error.message
  end

  # The options the panel actually rendered — the stored ones, or the same deterministic fallback
  # the view uses. Keeps the posted index aligned with what the reviewer saw.
  def decision_options_for(step)
    step.decision_options.presence || Llm::DecisionOptions.fallback_for(step)
  end

  # Scroll to whichever cell the reviewer should look at next.
  def focus_anchor(run)
    step = run.run_steps.where(status: "awaiting_human").order(:position).first ||
           run.run_steps.where(status: %w[pending queued running stale]).order(:position).first
    step && "run_step_#{step.id}"
  end

  def option_interpretation(option)
    Llm::FeedbackInterpreter::Result.new(
      intent: option["intent"],
      notes: option["notes"].presence || option["description"],
      reason: option["notes"],
      edits: option["edits"] || {},
      raw: option
    )
  end

  def interpretation_for(feedback)
    parsed = feedback.parsed || {}
    Llm::FeedbackInterpreter::Result.new(
      intent: parsed["intent"], notes: parsed["notes"], reason: parsed["reason"],
      edits: parsed["edits"] || {}, raw: parsed
    )
  end
end
