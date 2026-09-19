class RunsController < ApplicationController
  layout "notebook"

  def index
    load_runs
    @run = @runs.first
    render :show
  end

  def show
    load_runs
    @run = PipelineRunRecord.find(params[:id])
  end

  def create
    if params[:style_slug].blank? || params[:scene_spec_id].blank?
      return redirect_to runs_path, alert: "style_slug and scene_spec_id are required."
    end

    run = PipelineRunRecord.create!(
      run_id: "run_#{Date.current.strftime('%Y%m%d')}_#{SecureRandom.hex(2)}",
      mode: "speculative", status: "pending", scope: "full",
      style_slug: params[:style_slug], scene_spec_id: params[:scene_spec_id],
      kb_version: Workflow::PreflightCheck.call!(allow_dirty: true).kb_version,
      dossier_data: {
        "style_name" => params[:style_name].presence,
        "scene_image" => params[:scene_image].presence ||
                         "scene_templates/assets/#{params[:scene_spec_id]}.png"
      }.compact,
      started_at: Time.current
    )
    Workflow::CellRunner.prepare(run)
    redirect_to run_path(run), notice: "Run #{run.run_id} created."
  rescue Workflow::DirtyKnowledgeBaseError => e
    redirect_to runs_path, alert: e.message
  end

  def run_next
    run = PipelineRunRecord.find(params[:id])
    Workflow::CellRunner.queue_next(run)
    ExecuteRunJob.perform_later(run_id: run.id, mode: "next")
    head :accepted
  end

  def run_to_decision
    run = PipelineRunRecord.find(params[:id])
    Workflow::CellRunner.queue_next(run)
    ExecuteRunJob.perform_later(run_id: run.id, mode: "to_decision")
    head :accepted
  end

  def approve
    run = PipelineRunRecord.find(params[:id])
    if run.run_steps.any?(&:stale?)
      return redirect_to run_path(run), alert: "Re-run the stale cells before approving."
    end

    Workflow::DossierRefresher.call(run: run)
    run.update!(status: "approved", reviewed_at: Time.current, reviewer_notes: params[:notes])
    CommitRunJob.perform_later(run_id: run.run_id)
    redirect_to run_path(run), notice: "Run approved — committing."
  end

  def abandon
    run = PipelineRunRecord.find(params[:id])
    run.update!(status: "abandoned", reviewed_at: Time.current)
    redirect_to run_path(run), notice: "Run abandoned."
  end

  private

  def load_runs
    @runs = PipelineRunRecord.order(created_at: :desc).limit(50)
  end
end
