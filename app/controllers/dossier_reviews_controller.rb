class DossierReviewsController < ApplicationController
  def index
    @runs = PipelineRunRecord.where(status: "awaiting_dossier_review").order(dossier_ready_at: :desc)
  end

  def show
    @run = PipelineRunRecord.find_by!(run_id: params[:id])
  end

  def update
    @run = PipelineRunRecord.find_by!(run_id: params[:id])

    case params[:decision]
    when "approve"
      @run.update!(status: "approved", reviewed_at: Time.current, reviewer_notes: params[:notes])
      CommitRunJob.perform_later(run_id: @run.run_id)
    when "rerun"
      step = params.require(:step_id)
      @run.update!(status: "rerunning", reviewer_notes: params[:notes])
      RerunFromStepJob.perform_later(run_id: @run.run_id, step_id: step, guidance: params[:notes])
    when "abandon"
      @run.update!(status: "abandoned", reviewed_at: Time.current, reviewer_notes: params[:notes])
    end

    redirect_to dossier_reviews_path
  end
end
