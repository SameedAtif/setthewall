require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  test "index lists open gates" do
    piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test",
                                status: "awaiting_human")
    HumanGate.create!(piece_record: piece, step_id: "P2_7", gate_kind: "weekly_review",
                      status: "open", agent_proposal: "{}", context_snapshot: {},
                      opened_at: 1.minute.ago, notes: "Weekly review gate")

    get reviews_path
    assert_response :success
    assert_match(/Awaiting review/, response.body)
    assert_match(/P2_7/, response.body)
  end

  test "index lists failed pieces" do
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test",
                        status: "failed", current_step: "C1", last_error: "C1: boom")

    get reviews_path
    assert_response :success
    assert_match(/Failed pieces/, response.body)
    assert_match(/C1/, response.body)
  end
end
