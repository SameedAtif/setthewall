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
    expect(run.escalations.map { |e| e["step_id"] }).to include("P2_0", "P3_7")
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

  it "runs the style scope (Track A + B) and escalates its Tier 3 locks" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(Result.new(status: :ok, data: {}))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1", scope: "style")

    expect(run.scope).to eq("style")
    expect(run.step_results.map { |r| r["step_id"] }).to eq(described_class::STYLE_ORDER)
    expect(run.escalations.map { |e| e["step_id"] }).to include("A0", "A5", "B0", "B7")
    expect(run.dossier_markdown).to include("## Survey style candidates (A_IDEATE)")
    expect(run.dossier_markdown).to include("## Validate the style is worth pursuing (A0)")
  end

  it "runs the full scope across Track A, Track B, and the piece pipeline" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(Result.new(status: :ok, data: {}))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1", scope: "full")

    expect(run.scope).to eq("full")
    expect(run.step_results.map { |r| r["step_id"] }).to eq(described_class::FULL_ORDER)
  end

  it "rewinds on a blocking finding" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(Result.new(status: :awaiting_human, data: {}))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent(severity: "blocking")])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.step_results.filter_map { |r| r["disposition"] }).to include("rewind")
  end

  it "escalates a rewind with the blocking claim" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_return(Result.new(status: :awaiting_human, data: {}))
    allow(Agents::Registry).to receive(:for).and_return([fake_agent(severity: "blocking")])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.escalations.map { |e| e["reason"] }).to include("rewind")
  end

  it "gates P2_6 so placement QA runs, but leaves non-gated steps alone" do
    run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test")
    conductor = described_class.new(run)
    expect(conductor.send(:gated?, "P2_6")).to be(true)
    expect(conductor.send(:gated?, "P2_1")).to be(false)
  end

  describe "#clear_side_effects!" do
    it "clears chosen_url for a rewound C2" do
      piece = create(:piece_record, chosen_url: "u1")
      run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                                      piece_record: piece)
      described_class.new(run).send(:clear_side_effects!, "C2")
      expect(piece.reload.chosen_url).to be_nil
    end

    it "does nothing for a non-C2 step" do
      piece = create(:piece_record, chosen_url: "u1")
      run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                                      piece_record: piece)
      described_class.new(run).send(:clear_side_effects!, "A3")
      expect(piece.reload.chosen_url).to eq("u1")
    end
  end

  describe "#capture_reference_images!" do
    it "populates A1 curated images into dossier_data" do
      run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                                      dossier_data: {})
      result = Result.new(status: :awaiting_human,
                          data: { candidates: { "images" => [{ "url" => "u1" }, { "url" => "u2" }] } })
      described_class.new(run).send(:capture_reference_images!, result)
      expect(run.reload.dossier_data.dig("A1", "curated_images")).to eq(%w[u1 u2])
    end
  end

  describe "#capture_ideation_pick!" do
    it "threads the recommended candidate into the style name" do
      run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                                      dossier_data: { "style_name" => "original" })
      result = Result.new(status: :awaiting_human, data: { recommended_focus: "Gothic naturalist" })
      described_class.new(run).send(:capture_ideation_pick!, result)
      expect(run.reload.dossier_data["style_name"]).to eq("Gothic naturalist")
    end

    it "does nothing when no recommendation is present" do
      run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                                      dossier_data: { "style_name" => "original" })
      described_class.new(run).send(:capture_ideation_pick!, Result.new(status: :ok, data: {}))
      expect(run.reload.dossier_data["style_name"]).to eq("original")
    end
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

  it "records and escalates a step error instead of crashing" do
    allow(Workflow::PreflightCheck).to receive(:call!).and_return(kb_result)
    allow(Workflow::StepDispatcher).to receive(:call).and_raise("boom")
    allow(Agents::Registry).to receive(:for).and_return([fake_agent])

    run = described_class.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.status).to eq("awaiting_dossier_review")
    expect(run.step_results.first["status"]).to eq("failed")
    expect(run.escalations.map { |e| e["reason"] }).to include("step_error")
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
