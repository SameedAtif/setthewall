class PipelineController < ApplicationController
  def index
    @track_runs    = TrackRun.order(created_at: :desc).limit(20)
    @pieces        = PieceRecord.order(updated_at: :desc).limit(30)
    @open_gates    = HumanGate.open.includes(:piece_record, :track_run).order(opened_at: :desc).limit(30)
    @failed_pieces = PieceRecord.where(status: "failed").order(updated_at: :desc).limit(10)
    @failed_runs   = TrackRun.where(status: "failed").order(updated_at: :desc).limit(10)
    @surveys       = IdeationSurvey.order(created_at: :desc).limit(10)
    @latest_cycle  = latest_cycle_id
  end

  def ideate
    IdeateStylesJob.perform_later(direction: params[:direction].presence, count: params[:count].presence&.to_i)
    redirect_to root_path, notice: "Ideation survey queued — it'll appear in the list shortly."
  end

  def start_track_a
    StartTrackJob.perform_later(track: "track_a", style_slug: params[:style_slug], style_name: params[:style_name])
    redirect_to root_path, notice: "Track A queued for #{params[:style_slug]}."
  end

  def start_track_b
    StartTrackJob.perform_later(
      track: "track_b", style_slug: params[:style_slug], scene_template_id: params[:scene],
      scene_image: "scene_templates/assets/#{params[:scene]}.png"
    )
    redirect_to root_path, notice: "Track B queued for #{params[:scene]}."
  end

  def start_daily
    piece = Workflow::PipelineRun.start_daily(style_slug: params[:style], scene_spec_id: params[:scene])
    redirect_to root_path, notice: "Daily pipeline started. Piece ##{piece.id}."
  rescue Workflow::DirtyKnowledgeBaseError => e
    redirect_to root_path, alert: e.message
  end

  def refresh_stats
    Performance::EtsyStatsFetcher.call(date: Date.current)
    redirect_to root_path, notice: "Stats refreshed for #{PieceRecord.published.trustworthy.count} piece(s)."
  end

  def export
    result = Performance::WeeklyExport.call(week_ending: Date.current)
    redirect_to root_path, notice: "Export complete. Cycle: #{result[:cycle_id]}"
  end

  def propose
    cycle = params[:cycle].presence || latest_cycle_id
    return redirect_to root_path, alert: "No export found — run Export first." if cycle.blank?

    ProposeJob.perform_later(cycle_id: cycle)
    redirect_to kb_proposals_path, notice: "Proposal generation queued for #{cycle}. Review at /kb_proposals."
  end

  private

  def latest_cycle_id
    Dir[Rails.root.join("tmp", "evolution", "*_data.json")]
      .map { |f| File.basename(f, "_data.json") }
      .sort
      .last
  end
end
