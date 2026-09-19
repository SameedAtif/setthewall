require "rails_helper"

RSpec.describe Agents::ImageQa do
  def run_with(piece = nil, dossier_data: {})
    PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test",
                              piece_record: piece, dossier_data: dossier_data)
  end

  it "blocks when there are no candidates" do
    f = described_class.call(run: run_with, step_id: "C1", result: Object.new, context: {})
    expect(f).to include(an_object_having_attributes(severity: "blocking"))
  end

  it "passes a conforming batch" do
    piece = create(:piece_record, candidate_urls: ["https://x/1.jpg"])
    stub_llm(content: { "per_image" => [{ "index" => 1, "axis_mismatches" => [] }], "constraint_violations" => [] }) do
      f = described_class.call(run: run_with(piece), step_id: "C1", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end
  end

  it "advisories a non-conforming candidate" do
    piece = create(:piece_record, candidate_urls: ["https://x/1.jpg"])
    stub_llm(content: { "per_image" => [{ "index" => 1, "axis_mismatches" => ["mood"] }],
                        "constraint_violations" => [] }) do
      f = described_class.call(run: run_with(piece), step_id: "C1", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory"))
    end
  end

  it "blocks on constraint violations" do
    piece = create(:piece_record, candidate_urls: ["https://x/1.jpg"])
    stub_llm(content: { "per_image" => [{ "index" => 1, "axis_mismatches" => [] }],
                        "constraint_violations" => ["text"] }) do
      f = described_class.call(run: run_with(piece), step_id: "C1", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end
  end

  it "blocks when no candidate conforms" do
    piece = create(:piece_record, candidate_urls: ["https://x/1.jpg"])
    stub_llm(content: { "per_image" => [{ "index" => 1, "axis_mismatches" => ["mood"] }],
                        "constraint_violations" => [] }) do
      f = described_class.call(run: run_with(piece), step_id: "C2_finalists", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking", claim: a_string_including("No candidate")))
    end
  end

  it "advisories a candidate that does not depict its specified subject" do
    piece = create(:piece_record, candidate_urls: ["https://x/1.jpg"], candidate_subjects: ["cottage"])
    stub_llm(content: { "per_image" => [{ "index" => 1, "axis_mismatches" => [], "subject_conforms" => false }],
                        "constraint_violations" => [] }) do
      f = described_class.call(run: run_with(piece), step_id: "C1", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory", claim: a_string_including("subject")))
    end
  end

  it "blocks a near-replica of a single reference" do
    piece = create(:piece_record, candidate_urls: ["https://x/1.jpg"])
    stub_llm(content: { "per_image" => [{ "index" => 1, "axis_mismatches" => [],
                                          "max_reference_similarity" => 95 }],
                        "constraint_violations" => [] }) do
      f = described_class.call(run: run_with(piece), step_id: "C1", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking",
                                                       claim: a_string_including("near-replica")))
    end
  end

  it "advisories a candidate that misses the reference essence" do
    piece = create(:piece_record, candidate_urls: ["https://x/1.jpg"])
    stub_llm(content: { "per_image" => [{ "index" => 1, "axis_mismatches" => [],
                                          "palette_conforms" => false, "surface_conforms" => true,
                                          "motif_conforms" => true }],
                        "constraint_violations" => [] }) do
      f = described_class.call(run: run_with(piece), step_id: "C1", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory",
                                                       claim: a_string_including("reference essence")))
    end
  end

  it "advisories a batch that is not compositionally diverse" do
    piece = create(:piece_record, candidate_urls: ["https://x/1.jpg", "https://x/2.jpg"])
    descriptors = { "transition_position" => "centre", "transition_orientation" => "diagonal",
                    "seam_presence" => "trace", "motif_region_shape" => "band" }
    stub_llm(content: { "per_image" => [
                          { "index" => 1, "axis_mismatches" => [], "descriptors" => descriptors },
                          { "index" => 2, "axis_mismatches" => [], "descriptors" => descriptors }
                        ], "constraint_violations" => [] }) do
      f = described_class.call(run: run_with(piece), step_id: "C1", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory",
                                                       claim: a_string_including("diverse")))
    end
  end

  it "uses lifestyle photos for P3_1b" do
    piece = create(:piece_record, photos: { "a" => "https://x/p.jpg" })
    stub_llm(content: { "per_image" => [{ "index" => 1, "axis_mismatches" => [] }], "constraint_violations" => [] }) do
      f = described_class.call(run: run_with(piece), step_id: "P3_1b", result: Object.new, context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end
  end

  it "blocks for an uncovered step with no candidates" do
    f = described_class.call(run: run_with, step_id: "P3_1", result: Object.new, context: {})
    expect(f).to include(an_object_having_attributes(severity: "blocking"))
  end
end

RSpec.describe Agents::PlacementQa do
  def run_with(piece = nil)
    PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test", piece_record: piece)
  end

  def measurements(overrides = {})
    { "pixels_per_inch" => 24, "coverage_fraction" => 0.5, "drop_applied_inches" => 3.5,
      "furniture_gap_px" => 216, "group_width_px" => 900, "furniture_width_px" => 1200 }.merge(overrides)
  end

  def result_for(m)
    Struct.new(:data, :status, keyword_init: true).new(data: { measurements: m }, status: :ok)
  end

  it "passes a lookup step" do
    f = described_class.call(run: run_with, step_id: "P2_1", result: result_for({}), context: {})
    expect(f).to include(an_object_having_attributes(severity: "pass"))
  end

  it "blocks coverage in the forbidden mid-band" do
    f = described_class.call(run: run_with, step_id: "P2_6",
                             result: result_for(measurements("coverage_fraction" => 0.8)), context: {})
    expect(f).to include(an_object_having_attributes(severity: "blocking", claim: a_string_including("Coverage")))
  end

  it "blocks a wrong eye-level drop" do
    f = described_class.call(run: run_with, step_id: "P2_6",
                             result: result_for(measurements("drop_applied_inches" => 0.0)), context: {})
    expect(f).to include(an_object_having_attributes(severity: "blocking", claim: a_string_including("drop")))
  end

  it "blocks a furniture gap out of band in a seated room" do
    piece = create(:piece_record, room_type: "seated_room")
    f = described_class.call(run: run_with(piece), step_id: "P2_6",
                             result: result_for(measurements("furniture_gap_px" => 500)), context: {})
    expect(f).to include(an_object_having_attributes(severity: "blocking", claim: a_string_including("gap")))
  end

  it "blocks a group wider than the furniture" do
    f = described_class.call(run: run_with, step_id: "P2_6",
                             result: result_for(measurements("group_width_px" => 2000, "furniture_width_px" => 1000)), context: {})
    expect(f).to include(an_object_having_attributes(severity: "blocking", claim: a_string_including("Group width")))
  end

  it "passes a fully valid composite" do
    piece = create(:piece_record, room_type: "seated_room")
    f = described_class.call(run: run_with(piece), step_id: "P2_6", result: result_for(measurements), context: {})
    expect(f.map(&:severity)).not_to include("blocking")
  end
end

RSpec.describe Agents::Registry do
  it "maps a step to its agents" do
    expect(described_class.for("A2").map(&:agent_id)).to eq(["axis_qa"])
    expect(described_class.for("A1").map(&:agent_id)).to eq(["research_qa"])
    expect(described_class.for("A5")).to be_empty
  end

  it "validates coverage of the non-Tier-3 gated steps" do
    expect(described_class.validate_coverage!).to be(true)
  end
end

RSpec.describe Agents::BlindVerifier do
  def finding(severity)
    Agents::Finding.new(severity: severity, claim: "x", citations: [], payload: {})
  end

  let(:run) { PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test") }

  it "agrees when proposer and verifier reach the same worst severity" do
    stub_singleton(Agents::Registry, :for, ->(_id) { [Agents::AxisQa] }) do
      allow_any_instance_of(Agents::AxisQa).to receive(:evaluate).and_return([finding("pass")])
      outcome = described_class.call(run: run, step_id: "A2", result: Object.new, context: {},
                                     proposer_findings: [finding("pass")])
      expect(outcome.agreed).to be(true)
    end
  end

  it "diverges when severities differ" do
    stub_singleton(Agents::Registry, :for, ->(_id) { [Agents::AxisQa] }) do
      allow_any_instance_of(Agents::AxisQa).to receive(:evaluate).and_return([finding("blocking")])
      outcome = described_class.call(run: run, step_id: "A2", result: Object.new, context: {},
                                     proposer_findings: [finding("pass")])
      expect(outcome.agreed).to be(false)
      expect(outcome.divergence).to eq({ proposer: "pass", verifier: "blocking" })
    end
  end
end

RSpec.describe Agents::EvidenceQa do
  it "resolves real rule paths and rejects fabricated ones" do
    expect(described_class.resolves?("mood_markers.rules.scoring.mixed_result")).to be(true)
    expect(described_class.resolves?("mood_markers.rules.totally.invented")).to be(false)
    expect(described_class.resolves?("")).to be(false)
    expect(described_class.resolves?("no_such_file.rules.x")).to be(false)
  end

  it "marks each unresolved finding" do
    run = PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test")
    good = run.qa_findings.create!(step_id: "A2", agent_id: "axis_qa", severity: "pass",
                                   claim: "ok", citations: [{ "rule_path" => "mood_markers.rules.validation" }])
    bad  = run.qa_findings.create!(step_id: "A2", agent_id: "axis_qa", severity: "blocking",
                                   claim: "bad", citations: [{ "rule_path" => "mood_markers.rules.invented" }])

    unresolved = described_class.call(run: run)

    expect(unresolved.map(&:id)).to eq([bad.id])
    expect(good.reload.citations_resolved).to be(true)
    expect(bad.reload.citations_resolved).to be(false)
  end
end
