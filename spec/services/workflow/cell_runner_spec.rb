require "rails_helper"

RSpec.describe Workflow::CellRunner do
  # Deliberately avoid top-level constants — spec constants leak and collide across files.
  def step_result(status: :ok, data: {}, message: nil)
    Struct.new(:status, :data, :message, keyword_init: true)
          .new(status: status, data: data, message: message)
  end

  let(:run) { create(:pipeline_run_record, scope: "piece") }

  before do
    allow(Workflow::DecisionRules).to receive(:gated_step_ids).and_return([])
    allow(Agents::Registry).to receive(:for).and_return([])
    allow(Llm::CellSummarizer).to receive(:call).and_return("summary")
    allow(Llm::DecisionOptions).to receive(:call).and_return([])
  end

  it "materializes only the first cell until it runs" do
    described_class.prepare(run)

    expect(run.run_steps.map(&:step_id)).to eq(%w[C1])
    expect(run.run_steps.first).to be_pending
  end

  it "marks already-locked style steps skipped when preparing a full run" do
    full = create(:pipeline_run_record, scope: "full")
    allow(Workflow::RunSequencer).to receive(:locked_style?).and_return(true)

    described_class.prepare(full)

    expect(full.run_steps.where(status: "skipped").pluck(:step_id))
      .to match_array(Workflow::RunSequencer::STYLE_ORDER)
    expect(full.run_steps.find_by(step_id: "C1")).to be_pending
  end

  it "marks the next cell queued for immediate feedback" do
    described_class.prepare(run)

    step = described_class.queue_next(run)

    expect(step).to be_queued
    expect(run.reload.status).to eq("running")
  end

  it "reveals the next cell after a cell completes" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)

    described_class.prepare(run)
    described_class.run_next(run)

    expect(run.run_steps.order(:position).map(&:step_id)).to eq(%w[C1 C2])
  end

  it "records log lines on the cell while it runs" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)

    described_class.prepare(run)
    described_class.run_next(run)

    messages = run.run_steps.find_by(step_id: "C1").logs.map { |l| l["message"] }
    expect(messages).to include("Started C1")
    expect(messages).to include(a_string_matching(/Dispatching C1/))
  end

  it "clears a step's context override after running it" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)
    step = create(:run_step, pipeline_run_record: run, step_id: "C1", position: 0,
                             status: "pending", context_override: { "style_name" => "scoped" })

    described_class.run_until_gate(run)

    expect(step.reload.context_override).to eq({})
  end

  it "executes the next runnable cell and mirrors it into step_results" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call)
      .and_return(step_result(data: { "a" => 1 }, message: "ran"))

    described_class.run_next(run)

    step = run.run_steps.find_by(step_id: "C1")
    expect(step.status).to eq("done")
    expect(step.output).to eq({ "a" => 1 })
    expect(run.reload.step_results.first).to include("step_id" => "C1", "status" => "ok")
  end

  it "pauses at a human-only step and opens a gate" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(3)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)

    described_class.run_next(run)

    step = run.run_steps.find_by(step_id: "C1")
    expect(step.status).to eq("awaiting_human")
    expect(HumanGate.open.where(step_id: "C1")).to exist
  end

  it "stops at the first pause in run_until_gate" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1, 3)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)

    described_class.run_until_gate(run)

    expect(run.run_steps.where(status: "done").count).to eq(1)
    expect(run.run_steps.where(status: "awaiting_human").count).to eq(1)
  end

  it "continues past a pause in run_all and finalizes when nothing is awaiting" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)

    described_class.run_all(run)

    expect(run.run_steps.count).to eq(Workflow::RunSequencer::PIECE_ORDER.size)
    expect(run.reload.status).to eq("awaiting_dossier_review")
  end

  it "does not finalize while a gate is awaiting a decision" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1, 3)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)

    described_class.run_all(run)

    expect(run.run_steps.where(status: "awaiting_human")).to exist
    expect(run.reload.status).not_to eq("awaiting_dossier_review")
  end

  it "marks a failing step failed and stops" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call).and_raise("boom")

    described_class.run_until_gate(run)

    expect(run.run_steps.first.status).to eq("failed")
  end

  it "records the same step_results entry as the conductor for the same step" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call)
      .and_return(step_result(data: { "a" => 1 }, message: "ran"))

    conductor_run = create(:pipeline_run_record, scope: "piece")
    Agents::Conductor.new(conductor_run).send(:execute, "C1")

    cell_run = create(:pipeline_run_record, scope: "piece")
    described_class.run_next(cell_run)

    expect(cell_run.reload.step_results.first).to eq(conductor_run.reload.step_results.first)
  end
end
