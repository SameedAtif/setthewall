require "test_helper"

class StepDispatcherTest < ActiveSupport::TestCase
  def build_piece
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s",
                        kb_version: "dirty:test", status: "pending")
  end

  test "opens a HumanGate and pauses on awaiting_human" do
    piece = build_piece
    result = Workflow::StepDispatcher.call(step_id: "P2_7", piece: piece, context: {})

    assert result.awaiting_human?
    assert_equal "awaiting_human", piece.reload.status
    assert_equal "P2_7", piece.current_step

    gate = piece.open_gate
    assert gate.present?
    assert_equal "open", gate.status
    assert_equal "P2_7", gate.step_id
  end

  test "raises for an unknown step id" do
    piece = build_piece
    assert_raises(ArgumentError) do
      Workflow::StepDispatcher.call(step_id: "NOPE", piece: piece)
    end
  end

  test "tolerates piece: nil for pre-piece tracks" do
    result = Workflow::StepDispatcher.call(step_id: "P2_7", piece: nil, context: {})
    assert result.awaiting_human?
  end
end
