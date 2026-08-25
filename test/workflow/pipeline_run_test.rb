require "test_helper"

class PipelineRunTest < ActiveSupport::TestCase
  def piece(space_math:, piece_count:, placement_branch:)
    PieceRecord.new(space_math: space_math, piece_count: piece_count, placement_branch: placement_branch)
  end

  test "P2_1 branches to the 2x step for single" do
    assert_equal "P2_2a", Workflow::PipelineRun.next_step_after("P2_1", piece(space_math: "single", piece_count: 1, placement_branch: "single"))
  end

  test "P2_1 branches to the 2x step for set" do
    assert_equal "P2_2b", Workflow::PipelineRun.next_step_after("P2_1", piece(space_math: "set", piece_count: 3, placement_branch: "set"))
  end

  test "a single piece skips theme unification" do
    assert_equal "P2_4", Workflow::PipelineRun.next_step_after("P2_2a", piece(space_math: "single", piece_count: 1, placement_branch: "single"))
  end

  test "a multi-piece set routes through theme unification" do
    assert_equal "P2_3", Workflow::PipelineRun.next_step_after("P2_2b", piece(space_math: "set", piece_count: 3, placement_branch: "set"))
  end

  test "P3_8 is terminal" do
    assert_nil Workflow::PipelineRun.next_step_after("P3_8", piece(space_math: "single", piece_count: 1, placement_branch: "single"))
  end

  test "an unknown placement branch raises" do
    assert_raises(ArgumentError) do
      Phase2::BranchRouter.klass_for("nonsense")
    end
  end
end
