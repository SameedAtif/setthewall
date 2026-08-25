class HumanGatesController < ApplicationController
  def show
    @gate = HumanGate.find(params[:id])
    @piece = @gate.piece_record
    @agent_proposal = JSON.parse(@gate.agent_proposal || "{}")
  end

  def update
    @gate = HumanGate.find(params[:id])
    decision = params[:decision]   # "approved" | "rejected" | "edited"

    edits = params[:reviewer_edits].to_unsafe_h rescue {}
    notes = params[:notes]

    @gate.update!(
      status: decision,
      reviewer_edits: edits,
      reviewer_decision: (decision == "edited" ? edits.to_json : @gate.agent_proposal),
      notes: notes,
      closed_at: Time.current
    )

    # Only resume the piece if the reviewer approved or edited. Rejections leave the piece for
    # the human to decide the next move (usually: rerun the previous step with different context,
    # or abandon).
    ResumePieceJob.perform_later(gate_id: @gate.id) if %w[approved edited].include?(decision)

    redirect_to reviews_path, notice: "Gate ##{@gate.id} → #{decision}."
  end
end
