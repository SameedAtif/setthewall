require "rails_helper"

RSpec.describe Art::SubjectSceneSelector do
  Spec = Struct.new(:subject_research, :scene_research)

  def spec_with(subjects:, patterns:)
    Spec.new({ "recurring_subjects" => subjects }, { "scene_patterns" => patterns })
  end

  it "returns empty pairs when research is absent" do
    spec = spec_with(subjects: [], patterns: [])
    expect(described_class.pairs(spec, 3)).to eq([{ subject: nil, pattern: nil }] * 3)
  end

  it "produces distinct subject/pattern combinations without replacement" do
    spec = spec_with(
      subjects: [{ "subject" => "cottage" }, { "subject" => "moth" }],
      patterns: [{ "pattern_id" => "p1" }, { "pattern_id" => "p2" }]
    )
    pairs = described_class.pairs(spec, 4)
    expect(pairs.map { |p| [p[:subject]["subject"], p[:pattern]["pattern_id"]] }).to eq(
      [["cottage", "p1"], ["cottage", "p2"], ["moth", "p1"], ["moth", "p2"]]
    )
  end

  it "cycles when the batch exceeds the combination count" do
    spec = spec_with(subjects: [{ "subject" => "a" }], patterns: [{ "pattern_id" => "x" }])
    pairs = described_class.pairs(spec, 3)
    expect(pairs.map { |p| p[:subject]["subject"] }).to eq(%w[a a a])
  end
end
