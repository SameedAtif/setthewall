require "test_helper"

class StepsBaseTest < ActiveSupport::TestCase
  class OkStep < Steps::Base
    step id: "TEST_OK", mechanism: :lookup, ownership: "[AGENT-READY]"
    def perform = ok({ answer: 42 })
  end

  class HumanStep < Steps::Base
    step id: "TEST_HUMAN", mechanism: :human, ownership: "[HUMAN ONLY]"
    def perform = needs_human("please confirm", { proposed: "x" })
  end

  class FailStep < Steps::Base
    step id: "TEST_FAIL", mechanism: :lookup, ownership: "[AGENT-READY]"
    def perform = fail_step("boom", {})
  end

  def build_piece
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test", status: "pending")
  end

  test "ok produces an ok StepResult" do
    result = OkStep.call(piece: build_piece)
    assert result.ok?
    assert_equal({ answer: 42 }, result.data)
  end

  test "needs_human produces an awaiting_human StepResult" do
    result = HumanStep.call(piece: build_piece)
    assert result.awaiting_human?
    assert_equal "please confirm", result.message
  end

  test "fail_step produces a failed StepResult" do
    result = FailStep.call(piece: build_piece)
    assert result.failed?
  end

  test "call logs the outcome to the piece" do
    piece = build_piece
    OkStep.call(piece: piece)
    assert_equal 1, piece.reload.step_log.size
    assert_equal "TEST_OK", piece.step_log.first["step_id"]
    assert_equal "ok", piece.step_log.first["outcome"]
  end

  test "declares step_id, mechanism, and ownership" do
    assert_equal "TEST_OK", OkStep.step_id
    assert_equal :lookup, OkStep.mechanism
    assert_equal "[AGENT-READY]", OkStep.ownership
  end

  test "works with piece: nil (pre-piece tracks)" do
    assert HumanStep.call(piece: nil).awaiting_human?
  end
end
