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
      @run.update!(status: "approved", reviewed_at: Time.current, reviewer_notes: params[:notes],
                   reviewer_decisions: decisions_from(params))
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

  private

  def decisions_from(params)
    raw = params[:decisions]
    return {} if raw.blank?

    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    raw.slice("C2", "P3_7").each_with_object({}) do |(step, value), acc|
      acc[step] = value if value.is_a?(Hash)
    end
  end
end
