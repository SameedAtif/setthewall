require "rails_helper"

RSpec.describe Workflow::PipelineRun do
  def piece(space_math:, piece_count:, placement_branch:)
    PieceRecord.new(space_math: space_math, piece_count: piece_count, placement_branch: placement_branch)
  end

  it "routes P2_1 to the single branch step" do
    expect(described_class.next_step_after("P2_1", piece(space_math: "single", piece_count: 1, placement_branch: "single")))
      .to eq("P2_2a")
  end

  it "routes P2_1 to the set branch step" do
    expect(described_class.next_step_after("P2_1", piece(space_math: "set", piece_count: 3, placement_branch: "set")))
      .to eq("P2_2b")
  end

  it "skips theme unification for a single piece" do
    expect(described_class.next_step_after("P2_2a", piece(space_math: "single", piece_count: 1, placement_branch: "single")))
      .to eq("P2_4")
  end

  it "routes a set through theme unification" do
    expect(described_class.next_step_after("P2_2b", piece(space_math: "set", piece_count: 3, placement_branch: "set")))
      .to eq("P2_3")
  end

  it "is terminal after P3_8" do
    expect(described_class.next_step_after("P3_8", piece(space_math: "single", piece_count: 1, placement_branch: "single")))
      .to be_nil
  end

  it "advances along the straight line" do
    expect(described_class.next_step_after("C1", piece(space_math: "single", piece_count: 1, placement_branch: "single")))
      .to eq("C2")
  end

  it "returns nil for a step not in the daily sequence" do
    expect(described_class.next_step_after("A0", piece(space_math: "single", piece_count: 1, placement_branch: "single")))
      .to be_nil
  end

  it "raises on an unknown placement branch" do
    expect { Phase2::BranchRouter.klass_for("nonsense") }.to raise_error(ArgumentError)
  end
end
