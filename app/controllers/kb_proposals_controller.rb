class KbProposalsController < ApplicationController
  def index
    @open_proposals = KbProposal.open.order(:target_path, :created_at)
    @cycles = KbProposal.distinct.pluck(:cycle_id).sort.reverse
  end

  def show
    @proposal = KbProposal.find(params[:id])
    @current_content = read_target_safely(@proposal)
    @anti_regression_flags = KbEvolution::AntiRegressionScanner.call(@proposal)
  end

  def update
    @proposal = KbProposal.find(params[:id])
    decision = params[:decision]   # approved | rejected | edited

    @proposal.update!(
      status: decision,
      reviewer_edits: (decision == "edited" ? params[:reviewer_edits] : nil),
      reviewer_notes: params[:reviewer_notes],
      closed_at: Time.current
    )

    redirect_to kb_proposals_path,
                notice: "Proposal ##{@proposal.id} → #{decision}. #{'Run apply to write to disk.' if %w[approved edited].include?(decision)}"
  end

  def apply
    @proposal = KbProposal.find(params[:id])
    unless %w[approved edited].include?(@proposal.status)
      return redirect_to kb_proposals_path, alert: "Cannot apply a proposal that isn't approved or edited."
    end

    KbEvolution::Applier.call(proposal: @proposal)

    redirect_to kb_proposals_path,
                notice: "Applied proposal ##{@proposal.id}. Review with `git diff knowledge_base/` and commit."
  end

  private

  # Guarded read of a proposal's target file. Refuses (nil) when the resolved path
  # escapes knowledge_base/ — same invariant the Applier enforces on write.
  def read_target_safely(proposal)
    path = proposal.target_pathname.expand_path.to_s
    return nil unless path.start_with?(KbEvolution::Applier::ALLOWED_ROOT + "/")
    File.read(path)
  rescue SystemCallError
    nil
  end
end
