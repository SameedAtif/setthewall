require "rails_helper"

RSpec.describe "HumanGates", type: :request do
  it "ignores malformed reviewer edits JSON" do
    gate = create(:human_gate, agent_proposal: '{"recommended_hero":"url"}')
    patch human_gate_path(gate), params: { decision: "edited", reviewer_edits: "not json" }
    expect(gate.reload.reviewer_edits).to eq({})
  end
end

RSpec.describe "KbProposals", type: :request do
  it "applies an approved proposal" do
    path = Rails.root.join("knowledge_base/rules/test_apply_#{SecureRandom.hex(4)}.yml")
    path.write("meta:\n  source: t\n  citation: t\n  volatility: static\nrules:\n  x: 1\n")

    proposal = create(:kb_proposal, target_path: path.relative_path_from(Rails.root).to_s,
                                    change_type: "edit_snippet", old_snippet: "x: 1", new_snippet: "x: 2",
                                    status: "approved")

    post apply_kb_proposal_path(proposal)
    expect(response).to redirect_to(kb_proposals_path)
    expect(proposal.reload.status).to eq("applied")
    expect(File.read(path)).to include("x: 2")
  ensure
    File.delete(path) rescue nil
  end
end
