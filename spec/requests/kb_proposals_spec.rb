require "rails_helper"

RSpec.describe "KbProposals", type: :request do
  it "lists open proposals" do
    create(:kb_proposal)
    get kb_proposals_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("knowledge_base/rules/frame_material.yml")
  end

  it "flags anti-regression proposals on show" do
    proposal = create(:kb_proposal, rationale: "we should renew listings weekly")
    get kb_proposal_path(proposal)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("renewal_chasing")
  end

  it "approves a proposal" do
    proposal = create(:kb_proposal)
    patch kb_proposal_path(proposal), params: { decision: "approved" }
    expect(response).to redirect_to(kb_proposals_path)
    expect(proposal.reload.status).to eq("approved")
  end

  it "refuses to apply a non-approved proposal" do
    proposal = create(:kb_proposal, status: "open")
    post apply_kb_proposal_path(proposal)
    expect(response).to redirect_to(kb_proposals_path)
    expect(proposal.reload.status).to eq("open")
  end
end
