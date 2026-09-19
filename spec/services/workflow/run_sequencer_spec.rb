require "rails_helper"

RSpec.describe Workflow::RunSequencer do
  let(:run) { create(:pipeline_run_record, scope: "full") }

  before do
    allow(described_class).to receive(:locked_style?).and_return(false)
    allow(described_class).to receive(:locked_scene?).and_return(false)
  end

  describe ".order_for" do
    it "returns the full order by default" do
      expect(described_class.order_for(run)).to eq(described_class::FULL_ORDER)
    end

    it "always returns the full order even when the style spec is locked" do
      allow(described_class).to receive(:locked_style?).and_return(true)

      expect(described_class.order_for(run)).to eq(described_class::FULL_ORDER)
    end

    it "keeps only the piece order for a piece-scoped run" do
      run = create(:pipeline_run_record, scope: "piece")

      expect(described_class.order_for(run)).to eq(described_class::PIECE_ORDER)
    end
  end

  describe ".effective_order" do
    it "inserts the placement branch after P2_1" do
      piece = create(:piece_record, placement_branch: "single", space_math: "single")
      run = create(:pipeline_run_record, scope: "piece", piece_record: piece)

      order = described_class.effective_order(run)

      expect(order[order.index("P2_1") + 1]).to eq("P2_2a")
    end

    it "drops the conditional P2_3 for a single-piece set" do
      piece = create(:piece_record, placement_branch: "single", piece_count: 1)
      run = create(:pipeline_run_record, scope: "piece", piece_record: piece)

      expect(described_class.effective_order(run)).not_to include("P2_3")
    end

    it "keeps P2_3 for a multi-piece set" do
      piece = create(:piece_record, placement_branch: "set", piece_count: 3)
      run = create(:pipeline_run_record, scope: "piece", piece_record: piece)

      expect(described_class.effective_order(run)).to include("P2_3")
    end
  end

  describe ".next_runnable" do
    it "returns the first step that is not done or skipped" do
      run = create(:pipeline_run_record, scope: "piece")
      create(:run_step, pipeline_run_record: run, step_id: "C1", status: "done")

      expect(described_class.next_runnable(run)).to eq("C2")
    end

    it "returns a stale step so it can be re-run" do
      run = create(:pipeline_run_record, scope: "piece")
      create(:run_step, pipeline_run_record: run, step_id: "C1", status: "stale")

      expect(described_class.next_runnable(run)).to eq("C1")
    end

    it "blocks once a cell is awaiting a human decision" do
      run = create(:pipeline_run_record, scope: "piece")
      create(:run_step, pipeline_run_record: run, step_id: "C1", status: "awaiting_human")

      expect(described_class.next_runnable(run)).to be_nil
    end

    it "blocks while a cell is running" do
      run = create(:pipeline_run_record, scope: "piece")
      create(:run_step, pipeline_run_record: run, step_id: "C1", status: "running")

      expect(described_class.next_runnable(run)).to be_nil
    end
  end
end
