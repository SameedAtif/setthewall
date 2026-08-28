class HumanGatesController < ApplicationController
  def show
    @gate = HumanGate.find(params[:id])
    @piece = @gate.piece_record
    @agent_proposal = JSON.parse(@gate.agent_proposal || "{}")
  end

  def update
    @gate = HumanGate.find(params[:id])
    decision = params[:decision]   # "approved" | "rejected" | "edited"

    edits = parse_edits(params[:reviewer_edits])
    notes = params[:notes]

    @gate.update!(
      status: decision,
      reviewer_edits: edits,
      reviewer_decision: (decision == "edited" ? edits.to_json : @gate.agent_proposal),
      notes: notes,
      closed_at: Time.current
    )

    # Only resume the piece/track if the reviewer approved or edited. Rejections leave the
    # run for the human to decide the next move (usually: rerun the previous step with
    # different context, or abandon).
    if %w[approved edited].include?(decision)
      if @gate.track_run.present?
        Workflow::TrackRunner.resume(@gate)
      else
        ResumePieceJob.perform_later(gate_id: @gate.id)
      end
    end

    redirect_to reviews_path, notice: "Gate ##{@gate.id} → #{decision}."
  end

  private

  # The review form posts `reviewer_edits` as a JSON string in a textarea; a programmatic
  # client may post a hash instead. Accept both.
  def parse_edits(raw)
    return {} if raw.blank?
    return raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    JSON.parse(raw)
  rescue JSON::ParserError
    {}
  end
end
