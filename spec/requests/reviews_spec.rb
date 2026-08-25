require "rails_helper"

RSpec.describe "Reviews", type: :request do
  it "lists open gates" do
    piece = create(:piece_record, :awaiting_human)
    create(:human_gate, piece_record: piece, step_id: "P2_7", gate_kind: "weekly_review", notes: "Weekly review gate")

    get reviews_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Awaiting review")
    expect(response.body).to include("P2_7")
  end

  it "lists failed pieces" do
    create(:piece_record, :failed, current_step: "C1", last_error: "C1: boom")

    get reviews_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Failed pieces")
    expect(response.body).to include("C1")
  end
end
