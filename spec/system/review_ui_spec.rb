require "rails_helper"

RSpec.describe "Review UI", type: :system do
  it "lists an open gate" do
    piece = create(:piece_record, :awaiting_human)
    create(:human_gate, piece_record: piece, step_id: "P2_7", gate_kind: "weekly_review", notes: "Weekly review gate")

    visit root_path

    expect(page).to have_text("Awaiting review")
    expect(page).to have_text("P2_7")
    expect(page).to have_text("Weekly review gate")
  end

  it "shows approve / edit / reject actions" do
    piece = create(:piece_record, :awaiting_human)
    gate = create(:human_gate, piece_record: piece, step_id: "P3_2", gate_kind: "confirm_hero_shot",
                               agent_proposal: '{"recommended_hero":"url"}', notes: "Pick the hero")

    visit human_gate_path(gate)

    expect(page).to have_text("Agent proposal")
    expect(page).to have_button("Approve")
    expect(page).to have_button("Approve with edits")
    expect(page).to have_button("Reject")
  end
end
