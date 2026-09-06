require "rails_helper"

RSpec.describe Agents::Conductor do
  Result = Struct.new(:status, :data, :message, keyword_init: true) do
    def failed? = status == :failed
  end

  Finding = Struct.new(:severity, :claim, :citations, :payload, keyword_init: true) do
    def blocking? = severity == "blocking"
    def advisory? = severity == "advisory"
    def pass?     = severity == "pass"
  end

  let(:kb_result) { Workflow::PreflightCheck::Result.new(kb_version: "abc", dirty: false) }

  def fake_agent(severity: "pass")
    Class.new do
      define_singleton_method(:call) do |**_kwargs|
        [Finding.new(severity: severity, claim: "ok",
                     citations: [{ "rule_path" => "coverage_cap.rules" }], payload: {})]
      end
    end
  end

  it "runs the whole order speculatively and assembles a dossier" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(Result.new(status: :ok, data: {}))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.status).to eq("awaiting_dossier_review")
    expect(run.mode).to eq("speculative")
    expect(run.step_results.size).to eq(described_class::ORDER.size)
    expect(run.escalations.map { |e| e["step_id"] }).to include("A0", "A5", "B0", "B7", "P3_7")
    expect(run.dossier_markdown).to include("# Run #{run.run_id}")
  end

  it "escalates a Tier 2 divergence instead of tie-breaking" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(Result.new(status: :ok, data: {}))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])
    allow(Agents::BlindVerifier).to receive(:call).and_return(
      Agents::BlindVerifier::Outcome.new(agreed: false, verifier_findings: [],
                                         divergence: { proposer: "pass", verifier: "blocking" })
    )

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.escalations.map { |e| e["reason"] }).to include("verifier_divergence")
  end

  it "rewinds on a blocking finding" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(Result.new(status: :awaiting_human, data: {}))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent(severity: "blocking")])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.step_results.filter_map { |r| r["disposition"] }).to include("rewind")
  end

  it "accepts advisories with an acceptance note" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(Result.new(status: :awaiting_human, data: {}))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent(severity: "advisory")])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.status).to eq("awaiting_dossier_review")
  end

  it "escalates when the agent has no legal disposition" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call)
      .and_return(Result.new(status: :awaiting_human, data: { recommended_action: "reconsider" }))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.escalations.map { |e| e["reason"] }).to include("no_legal_agent_disposition")
  end

  describe ".build_piece" do
    it "seeds a piece with denormalised axes from the committed spec" do
      piece = described_class.build_piece(style_slug: "whimsigoth-v1",
                                          scene_spec_id: "behind_sofa_light_neutral", kb_version: "test")
      expect(piece).to be_a(PieceRecord)
      expect(piece.mood).to eq("bold_active")
      expect(piece.room_type).to eq("seated_room")
      expect(piece.color_role).to eq("color_burst")
    end

    it "returns nil when the spec is not locked" do
      expect(described_class.build_piece(style_slug: "nope", scene_spec_id: "x", kb_version: "t")).to be_nil
    end
  end
end
