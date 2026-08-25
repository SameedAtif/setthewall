require "test_helper"

class StatusMachineTest < ActiveSupport::TestCase
  def build(status: "pending")
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s",
                        kb_version: "dirty:test", status: status)
  end

  test "rejects an illegal transition" do
    piece = build(status: "complete")
    assert_raises(Workflow::InvalidTransition) do
      Workflow::StatusMachine.transition!(piece, to: "running")
    end
  end

  test "allows pending → running → awaiting_human → running" do
    piece = build(status: "pending")
    Workflow::StatusMachine.transition!(piece, to: "running", current_step: "C1")
    assert_equal "running", piece.reload.status
    assert_equal "C1", piece.current_step

    Workflow::StatusMachine.transition!(piece, to: "awaiting_human")
    assert_equal "awaiting_human", piece.reload.status

    Workflow::StatusMachine.transition!(piece, to: "running")
    assert_equal "running", piece.reload.status
  end

  test "sets last_error only on failed transition" do
    piece = build(status: "running")
    Workflow::StatusMachine.transition!(piece, to: "failed", last_error: "boom")
    assert_equal "boom", piece.reload.last_error

    piece.update!(status: "running")
    Workflow::StatusMachine.transition!(piece, to: "pending")
    assert_nil piece.reload.last_error
  end
end
