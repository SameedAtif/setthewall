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

  it "resumes a track gate via the TrackRunner" do
    run = create(:track_run, status: "awaiting_human", current_step: "A0")
    gate = create(:human_gate, track_run: run, step_id: "A0", status: "open", piece_record: nil)
    expect(Workflow::TrackRunner).to receive(:resume).with(gate)
    patch human_gate_path(gate), params: { decision: "approved" }
    expect(response).to redirect_to(reviews_path)
  end

  it "renders A0 findings as structured paragraphs instead of raw JSON" do
    proposal = {
      "findings" => {
        "findings" => [
          { "theme" => "Textured florals", "independent_shops" => 3,
            "competition_density" => "Moderate", "cross_check_platform" => "Pinterest",
            "cross_check_confirmed" => true,
            "demand_to_competition_verdict" => "Best bet: strong demand" }
        ],
        "single_recommended_focus" => "Ensō minimalist print",
        "recommendation_reasoning" => "Best demand-to-competition ratio.",
        "methodology_caveats" => "Structural estimate, not numeric."
      },
      "search_calls_made" => 2,
      "brief" => "Research what sells..."
    }
    run  = create(:track_run, status: "awaiting_human", current_step: "A0")
    gate = create(:human_gate, track_run: run, step_id: "A0", status: "open", piece_record: nil,
                               agent_proposal: proposal.to_json)

    get human_gate_path(gate)

    expect(response.body).to include("Textured florals")
    expect(response.body).to include("Best bet: strong demand")
    expect(response.body).to include("Recommended focus")
    expect(response.body).to include("Methodology caveats")
    expect(response.body).to include("cross-checked")
    expect(response.body).to include("2 live searches")
    expect(response.body).not_to include("competition_density")  # rendered as a "Competition" row, not a raw key
  end
end
