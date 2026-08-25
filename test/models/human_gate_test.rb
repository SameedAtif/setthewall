require "test_helper"

class HumanGateTest < ActiveSupport::TestCase
  def build_piece
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test", status: "awaiting_human")
  end

  test "validates status inclusion" do
    gate = HumanGate.new(piece_record: build_piece, step_id: "P3_2", gate_kind: "confirm_hero_shot", status: "bogus")
    assert_not gate.valid?
  end

  test "effective_output returns the agent proposal on approve" do
    gate = HumanGate.new(status: "approved", agent_proposal: '{"mood":"calm_ordered"}')
    assert_equal({ "mood" => "calm_ordered" }, gate.effective_output)
  end

  test "effective_output returns the reviewer decision when present" do
    gate = HumanGate.new(status: "edited", reviewer_decision: '{"mood":"bold_active"}')
    assert_equal({ "mood" => "bold_active" }, gate.effective_output)
  end

  test "duration_seconds is nil until closed" do
    gate = HumanGate.new(opened_at: 1.minute.ago)
    assert_nil gate.duration_seconds
    gate.closed_at = Time.current
    assert_in_delta 60, gate.duration_seconds, 2
  end
end
