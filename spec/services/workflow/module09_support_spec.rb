require "rails_helper"

RSpec.describe Context::Assembler do
  def run_with(results)
    PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                              style_slug: "s", scene_spec_id: "sc", step_results: results)
  end

  it "returns base context for an unmapped step" do
    ctx = described_class.for("B0", run_with([]))
    expect(ctx).to eq({ style_slug: "s", scene_spec_id: "sc" })
  end

  it "carries A0's style_name_used into A1" do
    run = run_with([{ "step_id" => "A0", "data" => { "style_name_used" => "Ensō print" } }])
    expect(described_class.for("A1", run)[:style_name]).to eq("Ensō print")
  end

  it "carries the A2-A5 axes" do
    run = run_with([
      { "step_id" => "A0", "data" => { "style_name_used" => "Ensō print" } },
      { "step_id" => "A1", "data" => { "curated_images" => %w[u1 u2] } },
      { "step_id" => "A2", "data" => { "mood" => "calm_ordered" } },
      { "step_id" => "A3", "data" => { "content_type" => "minimalist_modern" } },
      { "step_id" => "A4", "data" => { "frame_form" => "angular" } }
    ])
    ctx = described_class.for("A5", run)
    expect(ctx).to include(style_name: "Ensō print", mood: "calm_ordered",
                           content_type: "minimalist_modern", frame_form: "angular")
  end

  it "provisionally picks C2 finalists and chosen" do
    piece = create(:piece_record, candidate_urls: %w[u1 u2 u3 u4 u5])
    run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                                    style_slug: "s", scene_spec_id: "sc", piece_record: piece)
    ctx = described_class.for("C2", run)
    expect(ctx[:finalist_urls]).to eq(%w[u1 u2 u3])
    expect(ctx[:chosen_url]).to eq("u1")
  end
end

RSpec.describe Workflow::GateCloser do
  Finding = Struct.new(:severity, :claim, :citations, :payload, keyword_init: true) do
    def blocking? = severity == "blocking"
    def advisory? = severity == "advisory"
    def pass?     = severity == "pass"
  end

  it "records a rejected gate with citations" do
    run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test")
    finding = Finding.new(severity: "blocking", claim: "mixed", citations: [{ "rule_path" => "x" }], payload: {})

    expect {
      described_class.call(run: run, step_id: "A2", verdict: "unresolved_input",
                           disposition: "rewind", reviewer_kind: "agent", findings: [finding])
    }.to change(HumanGate, :count).by(1)

    gate = HumanGate.last
    expect(gate.step_id).to eq("A2")
    expect(gate.verdict).to eq("unresolved_input")
    expect(gate.reviewer_kind).to eq("agent")
    expect(gate.status).to eq("rejected")
    expect(gate.citations).to eq([{ "rule_path" => "x" }])
  end

  it "maps approve to approved and edit to edited" do
    expect(described_class.status_for("approve")).to eq("approved")
    expect(described_class.status_for("edit")).to eq("edited")
    expect(described_class.status_for("retry")).to eq("rejected")
  end
end

RSpec.describe Dossier::Builder do
  it "assembles the report sections" do
    run = PipelineRunRecord.create!(run_id: "run-x", kb_version: "abc", style_slug: "japandi",
                                    scene_spec_id: "s1", step_results: [
                                      { "step_id" => "A0", "status" => "awaiting_human",
                                        "verdict" => "clean", "disposition" => "approve" }
                                    ], escalations: [{ "step_id" => "A5", "reason" => "tier_3_gate" }])
    run.qa_findings.create!(step_id: "A0", agent_id: "research_qa", severity: "pass",
                            claim: "clean", citations: [])
    run.qa_findings.create!(step_id: "A1", agent_id: "research_qa", severity: "advisory",
                            claim: "weak sources", citations: [])

    markdown = described_class.call(run: run)

    expect(markdown).to include("# Run run-x — japandi / s1")
    expect(markdown).to include("## Open questions")
    expect(markdown).to include("- A5: tier_3_gate")
    expect(markdown).to include("## Step by step")
    expect(markdown).to include("- A0: awaiting_human (clean → approve)")
    expect(markdown).to include("## Why we think this will work")
    expect(markdown).to include("- clean")
    expect(markdown).to include("## What we could not verify")
    expect(markdown).to include("- weak sources")
    expect(markdown).to include("## If you approve")
  end
end
