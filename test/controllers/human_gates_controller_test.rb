require "test_helper"

class HumanGatesControllerTest < ActionDispatch::IntegrationTest
  def build_gate(status: "open")
    piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test",
                                status: "awaiting_human")
    HumanGate.create!(piece_record: piece, step_id: "P3_2", gate_kind: "confirm_hero_shot",
                      status: status, agent_proposal: '{"recommended_hero":"url"}',
                      context_snapshot: {}, opened_at: 1.minute.ago, notes: "Pick the hero shot")
  end

  test "show renders the agent proposal" do
    gate = build_gate
    get human_gate_path(gate)
    assert_response :success
    assert_match(/recommended_hero/, response.body)
  end

  test "update approves a gate and enqueues a resume job" do
    gate = build_gate
    assert_enqueued_with(job: ResumePieceJob) do
      patch human_gate_path(gate), params: { decision: "approved" }
    end
    assert_redirected_to reviews_path
    assert_equal "approved", gate.reload.status
    assert gate.reload.closed_at.present?
  end

  test "update rejects a gate without enqueuing a job" do
    gate = build_gate
    assert_no_enqueued_jobs do
      patch human_gate_path(gate), params: { decision: "rejected" }
    end
    assert_equal "rejected", gate.reload.status
  end

  test "update with edits records reviewer_edits (JSON string from the form)" do
    gate = build_gate
    patch human_gate_path(gate), params: { decision: "edited", reviewer_edits: '{"recommended_hero":"other"}' }
    assert_equal "edited", gate.reload.status
    assert_equal({ "recommended_hero" => "other" }, gate.reload.reviewer_edits)
  end
end
