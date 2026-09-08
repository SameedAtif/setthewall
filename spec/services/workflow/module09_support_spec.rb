require "rails_helper"

RSpec.describe Context::Assembler do
  def run_with(results)
    PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                              style_slug: "s", scene_spec_id: "sc", step_results: results)
  end

  it "returns base context for an unmapped step" do
    ctx = described_class.for("B0", run_with([]))
    expect(ctx).to include(style_slug: "s", scene_spec_id: "sc", scene_template_id: "sc",
                           scene_name: "sc", template_ref: "scene_templates/sc.yml")
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

  it "assembles B6 context from A3, B1, and B2" do
    run = run_with([
      { "step_id" => "A3", "data" => { "result" => { "content_type" => "minimalist_modern" } } },
      { "step_id" => "B1", "data" => { "wall_condition" => "neutral" } },
      { "step_id" => "B2", "data" => { "furniture_weight" => "light" } }
    ])
    ctx = described_class.for("B6", run)
    expect(ctx).to include(content_type: "minimalist_modern", wall_condition: "neutral",
                           furniture_weight: "light")
  end

  it "assembles B7 axes from B1-B6 and provisionally confirms the lock" do
    run = run_with([
      { "step_id" => "B1", "data" => { "wall_condition" => "neutral" } },
      { "step_id" => "B2", "data" => { "furniture_weight" => "light" } },
      { "step_id" => "B3", "data" => { "room_type" => "seated_room" } },
      { "step_id" => "B4", "data" => { "room_shape" => "none" } },
      { "step_id" => "B5", "data" => { "space_math" => "single" } },
      { "step_id" => "B6", "data" => { "color_role" => "line_only" } }
    ])
    ctx = described_class.for("B7", run)
    expect(ctx[:axes]).to eq(wall_condition: "neutral", furniture_weight: "light",
                             room_type: "seated_room", room_shape: "none",
                             space_math: "single", color_role: "line_only")
    expect(ctx[:confirmed]).to be(true)
  end

  it "provisionally confirms the A5 lock" do
    run = run_with([
      { "step_id" => "A2", "data" => { "result" => { "mood" => "calm_ordered" } } },
      { "step_id" => "A3", "data" => { "result" => { "content_type" => "minimalist_modern" } } },
      { "step_id" => "A4", "data" => { "result" => { "frame_form" => "angular" } } }
    ])
    expect(described_class.for("A5", run)[:confirmed]).to be(true)
  end

  it "does not thread a rewinded step's value" do
    run = run_with([
      { "step_id" => "A2", "data" => { "result" => { "mood" => "calm_ordered" } }, "disposition" => "approve" },
      { "step_id" => "A3", "data" => { "result" => { "content_type" => "minimalist_modern" } }, "disposition" => "rewind" },
      { "step_id" => "A4", "data" => { "result" => { "frame_form" => "angular" } }, "disposition" => "approve" }
    ])
    ctx = described_class.for("A5", run)
    expect(ctx[:content_type]).to be_nil
    expect(ctx[:mood]).to eq("calm_ordered")
  end

  it "does not provisionally confirm A5 when an axis is tainted" do
    run = run_with([
      { "step_id" => "A3", "data" => { "result" => { "content_type" => "minimalist_modern" } }, "disposition" => "rewind" }
    ])
    expect(described_class.for("A5", run)[:confirmed]).to be_nil
  end

  it "does not provisionally confirm B7 when a scene axis is tainted" do
    run = run_with([
      { "step_id" => "B1", "data" => { "wall_condition" => "neutral" } },
      { "step_id" => "B6", "data" => { "color_role" => "line_only" }, "disposition" => "rewind" }
    ])
    ctx = described_class.for("B7", run)
    expect(ctx[:axes][:color_role]).to be_nil
    expect(ctx[:confirmed]).to be_nil
  end

  it "treats a failed step as tainted" do
    run = run_with([
      { "step_id" => "A4", "status" => "failed", "data" => { "error" => "boom" } }
    ])
    ctx = described_class.for("A5", run)
    expect(ctx[:frame_form]).to be_nil
    expect(ctx[:confirmed]).to be_nil
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
    expect(markdown).to include("Lock the style-level entry (A5) — needs your decision")
    expect(markdown).to include("## Validate the style is worth pursuing (A0) — needs your review")
    expect(markdown).to include("## Why we think this will work")
    expect(markdown).to include("- clean")
    expect(markdown).to include("## What we could not verify")
    expect(markdown).to include("- weak sources")
    expect(markdown).to include("## If you approve")
  end

  it "renders step images relatively and shows listing data" do
    src = Rails.root.join("tmp", "test_images")
    src.mkpath
    %w[a.jpg b.jpg].each { |f| FileUtils.touch(src.join(f)) }

    piece = create(:piece_record, listing_title: "Celestial Sun Moon Print",
                                  listing_tags: %w[celestial sun moon])
    run = PipelineRunRecord.create!(run_id: "run-img", kb_version: "abc", style_slug: "whimsigoth-v1",
                                    scene_spec_id: "behind_sofa_light_neutral", piece_record: piece,
                                    step_results: [
                                      { "step_id" => "C1", "status" => "ok",
                                        "data" => { "candidate_urls" => [src.join("a.jpg").to_s] } },
                                      { "step_id" => "P2_6", "status" => "ok",
                                        "data" => { "composite_url" => src.join("b.jpg").to_s } }
                                    ], escalations: [])

    markdown = described_class.call(run: run)

    expect(markdown).to include("![a.jpg](images/a.jpg)")
    expect(markdown).to include("![b.jpg](images/b.jpg)")
    expect(Rails.root.join("tmp", "runs", "run-img", "images", "a.jpg").exist?).to be(true)
    expect(markdown).to include("Celestial Sun Moon Print")
    expect(markdown).to include("celestial, sun, moon")
  ensure
    FileUtils.rm_rf(src)
    FileUtils.rm_rf(Rails.root.join("tmp", "runs", "run-img"))
  end

  it "falls back to the original path when an image file is missing" do
    piece = create(:piece_record)
    run = PipelineRunRecord.create!(run_id: "run-miss", kb_version: "abc", style_slug: "whimsigoth-v1",
                                    scene_spec_id: "behind_sofa_light_neutral", piece_record: piece,
                                    step_results: [
                                      { "step_id" => "C1", "status" => "ok",
                                        "data" => { "candidate_urls" => ["/nonexistent/missing.jpg"] } }
                                    ], escalations: [])

    expect(described_class.call(run: run)).to include("![missing.jpg](/nonexistent/missing.jpg)")
  end

  it "renders A0 research findings" do
    run = PipelineRunRecord.create!(run_id: "run-res", kb_version: "abc", style_slug: "japandi",
                                    scene_spec_id: "s1", step_results: [
                                      { "step_id" => "A0", "status" => "awaiting_human", "message" => "x",
                                        "data" => { "findings" => { "findings" => [
                                          { "theme" => "Celestial", "demand_to_competition_verdict" => "Produce",
                                            "independent_shops" => 5, "competition_density" => "medium",
                                            "cross_check_confirmed" => true, "cross_check_platform" => "Pinterest" }
                                        ] } } }
                                    ], escalations: [])

    markdown = described_class.call(run: run)
    expect(markdown).to include("**Celestial** — Produce")
    expect(markdown).to include("cross-check confirmed via Pinterest")
  end

  it "renders a prompt and searches in a step section" do
    run = PipelineRunRecord.create!(run_id: "run-rich", kb_version: "abc", style_slug: "japandi",
                                    scene_spec_id: "s1", step_results: [
                                      { "step_id" => "A6", "status" => "ok",
                                        "data" => { "prompt" => "Describe the subjects.",
                                                    "searches" => [{ "query" => "whimsigoth wall art",
                                                                     "result_urls" => ["https://x/1"],
                                                                     "image_urls" => ["https://x/img.jpg"] }] } }
                                    ], escalations: [])

    markdown = described_class.call(run: run)
    expect(markdown).to include("## Research recurring subjects (A6) — completed")
    expect(markdown).to include("Describe the subjects.")
    expect(markdown).to include("whimsigoth wall art")
    expect(markdown).to include("https://x/1")
  end
end
