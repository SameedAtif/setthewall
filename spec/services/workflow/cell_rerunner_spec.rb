require "rails_helper"

RSpec.describe Workflow::CellRerunner do
  def step_result
    Struct.new(:status, :data, :message, keyword_init: true)
          .new(status: :ok, data: { "reran" => true }, message: nil)
  end

  # A gated step closes with an agent disposition, which needs at least one cited finding.
  def fake_agent
    finding = Struct.new(:severity, :claim, :citations, :payload, keyword_init: true) do
      def blocking? = severity == "blocking"
      def advisory? = severity == "advisory"
      def pass? = severity == "pass"
    end.new(severity: "pass", claim: "ok", citations: [{ "rule_path" => "x" }], payload: {})
    Class.new do
      define_singleton_method(:call) { |**_kwargs| [finding] }
    end
  end

  let(:run) { create(:pipeline_run_record, scope: "piece") }

  before do
    allow(Workflow::DecisionRules).to receive(:gated_step_ids).and_return([])
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])
    allow(Llm::CellSummarizer).to receive(:call).and_return("summary")
    allow(Llm::DecisionOptions).to receive(:call).and_return([])
  end

  def cell(step_id, position, status)
    create(:run_step, pipeline_run_record: run, step_id: step_id, position: position, status: status)
  end

  it "resets the cell, re-runs it, and marks everything after it stale" do
    c1 = cell("C1", 0, "done")
    c2 = cell("C2", 1, "done")
    p0 = cell("P2_0", 2, "done")
    p1 = cell("P2_1", 3, "done")

    described_class.call(run_step: c2)

    expect(c1.reload.status).to eq("done")
    expect(c2.reload.status).to eq("done")
    expect(p0.reload.status).to eq("stale")
    expect(p1.reload.status).to eq("stale")
  end

  it "drops stale cells from the mirrored step_results" do
    cell("C1", 0, "done")
    c2 = cell("C2", 1, "done")
    cell("P2_0", 2, "done")

    described_class.call(run_step: c2)

    expect(run.reload.step_results.map { |r| r["step_id"] }).to eq(%w[C1 C2])
  end
end
