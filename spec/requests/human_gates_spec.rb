require "rails_helper"

RSpec.describe "HumanGates", type: :request do
  def build_gate(status: "open")
    piece = create(:piece_record, :awaiting_human)
    create(:human_gate, piece_record: piece, step_id: "P3_2", gate_kind: "confirm_hero_shot",
                        agent_proposal: '{"recommended_hero":"url"}', notes: "Pick the hero shot", status: status)
  end

  it "shows the agent proposal" do
    gate = build_gate
    get human_gate_path(gate)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("recommended_hero")
  end

  it "approves a gate and enqueues a resume job" do
    gate = build_gate
    expect { patch human_gate_path(gate), params: { decision: "approved" } }
      .to have_enqueued_job(ResumePieceJob)
    expect(response).to redirect_to(reviews_path)
    expect(gate.reload.status).to eq("approved")
    expect(gate.reload.closed_at).to be_present
  end

  it "rejects a gate without enqueuing a job" do
    gate = build_gate
    expect { patch human_gate_path(gate), params: { decision: "rejected" } }.not_to have_enqueued_job
    expect(gate.reload.status).to eq("rejected")
  end

  it "records reviewer edits from the form's JSON string" do
    gate = build_gate
    patch human_gate_path(gate), params: { decision: "edited", reviewer_edits: '{"recommended_hero":"other"}' }
    expect(gate.reload.status).to eq("edited")
    expect(gate.reload.reviewer_edits).to eq({ "recommended_hero" => "other" })
  end
end
