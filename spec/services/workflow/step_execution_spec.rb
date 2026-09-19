require "rails_helper"

RSpec.describe Workflow::StepExecution do
  # Deliberately avoid top-level constants — spec constants leak and collide across files.
  def step_result(status: :ok, data: {}, message: nil)
    Struct.new(:status, :data, :message, keyword_init: true)
          .new(status: status, data: data, message: message)
  end

  def finding(severity: "pass")
    Struct.new(:severity, :claim, :citations, :payload, keyword_init: true) do
      def blocking? = severity == "blocking"
      def advisory? = severity == "advisory"
      def pass? = severity == "pass"
    end.new(severity: severity, claim: "ok", citations: [{ "rule_path" => "x" }], payload: {})
  end

  def fake_agent(severity: "pass")
    finding_obj = finding(severity: severity)
    Class.new do
      define_singleton_method(:call) { |**_kwargs| [finding_obj] }
    end
  end

  let(:run) { create(:pipeline_run_record) }

  before { allow(Agents::Registry).to receive(:for).and_return([]) }

  it "returns a non-paused outcome for an ungated step" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::DecisionRules).to receive(:gated_step_ids).and_return([])
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result(data: { "a" => 1 }))

    outcome = described_class.call(run: run, step_id: "P2_1")

    expect(outcome).to be_ok
    expect(outcome).not_to be_paused
  end

  it "pauses and escalates a human-only (tier 3) step" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(3)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)

    outcome = described_class.call(run: run, step_id: "A0")

    expect(outcome).to be_paused
    expect(run.reload.escalations.map { |e| e["reason"] }).to include("tier_3_gate")
  end

  it "runs QA and closes a gate on a gated step" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(2)
    allow(Workflow::DecisionRules).to receive(:gated_step_ids).and_return(["P2_6"])
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])
    allow(Agents::BlindVerifier).to receive(:call).and_return(
      Agents::BlindVerifier::Outcome.new(agreed: true, verifier_findings: [], divergence: {})
    )

    outcome = described_class.call(run: run, step_id: "P2_6")

    expect(outcome.disposition).to eq("approve")
    expect(HumanGate.where(step_id: "P2_6").count).to eq(1)
  end

  it "escalates a verifier divergence at tier 2" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(2)
    allow(Workflow::DecisionRules).to receive(:gated_step_ids).and_return(["B3"])
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result)
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])
    allow(Agents::BlindVerifier).to receive(:call).and_return(
      Agents::BlindVerifier::Outcome.new(agreed: false, verifier_findings: [],
                                         divergence: { "proposer" => "pass", "verifier" => "blocking" })
    )

    outcome = described_class.call(run: run, step_id: "B3")

    expect(outcome.disposition).to be_nil
    expect(run.reload.escalations.map { |e| e["reason"] }).to include("verifier_divergence")
  end

  it "rewinds on a blocking finding and clears side effects" do
    piece = create(:piece_record, chosen_url: "u1")
    run = create(:pipeline_run_record, piece_record: piece)
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(2)
    allow(Workflow::DecisionRules).to receive(:gated_step_ids).and_return(["C2"])
    allow(Workflow::StepDispatcher).to receive(:call).and_return(step_result(status: :awaiting_human))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent(severity: "blocking")])

    outcome = described_class.call(run: run, step_id: "C2")

    expect(outcome.disposition).to eq("rewind")
    expect(piece.reload.chosen_url).to be_nil
    expect(run.reload.escalations.map { |e| e["reason"] }).to include("rewind")
  end

  it "records a step error as a failed outcome instead of raising" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::StepDispatcher).to receive(:call).and_raise("boom")

    outcome = described_class.call(run: run, step_id: "P3_3")

    expect(outcome).to be_failed
    expect(run.reload.escalations.map { |e| e["reason"] }).to include("step_error")
  end

  it "captures A1 reference images into dossier_data" do
    allow(Workflow::DecisionRules).to receive(:tier_for).and_return(1)
    allow(Workflow::DecisionRules).to receive(:gated_step_ids).and_return([])
    allow(Workflow::StepDispatcher).to receive(:call).and_return(
      step_result(data: { candidates: { "images" => [{ "url" => "u1" }] } })
    )

    described_class.call(run: run, step_id: "A1")

    expect(run.reload.dossier_data.dig("A1", "curated_images")).to eq(%w[u1])
  end
end
