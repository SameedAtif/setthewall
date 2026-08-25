require "rails_helper"

RSpec.describe KbProposal do
  it "rejects a target_path outside knowledge_base/" do
    proposal = build(:kb_proposal, target_path: "app/models/piece_record.rb")
    expect(proposal).not_to be_valid
    expect(proposal.errors[:target_path]).to include("is invalid")
  end

  it "accepts a target_path inside knowledge_base/" do
    expect(build(:kb_proposal)).to be_valid
  end

  it "prefers reviewer edits in effective_new_snippet" do
    proposal = build(:kb_proposal, new_snippet: "claude", status: "edited", reviewer_edits: "reviewer")
    expect(proposal.effective_new_snippet).to eq("reviewer")

    proposal.status = "approved"
    expect(proposal.effective_new_snippet).to eq("claude")
  end

  it "validates change_type inclusion" do
    expect(build(:kb_proposal, change_type: "nonsense")).not_to be_valid
  end
end
