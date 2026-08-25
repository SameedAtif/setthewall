require "application_system_test_case"

class ReviewUiTest < ApplicationSystemTestCase
  test "review index lists an open gate" do
    piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test",
                                status: "awaiting_human")
    HumanGate.create!(piece_record: piece, step_id: "P2_7", gate_kind: "weekly_review",
                      status: "open", agent_proposal: "{}", context_snapshot: {},
                      opened_at: 1.minute.ago, notes: "Weekly review gate")

    visit root_path

    assert_text "Awaiting review"
    assert_text "P2_7"
    assert_text "Weekly review gate"
  end

  test "gate show page offers approve / edit / reject" do
    piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test",
                                status: "awaiting_human")
    gate = HumanGate.create!(piece_record: piece, step_id: "P3_2", gate_kind: "confirm_hero_shot",
                             status: "open", agent_proposal: '{"recommended_hero":"url"}',
                             context_snapshot: {}, opened_at: 1.minute.ago, notes: "Pick the hero")

    visit human_gate_path(gate)

    assert_text "Agent proposal"
    assert_button "Approve"
    assert_button "Approve with edits"
    assert_button "Reject"
  end
end
