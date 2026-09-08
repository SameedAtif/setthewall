require "rails_helper"

RSpec.describe Steps::TrackA::SubjectResearch do
  def ctx(slug = "s")
    { style_slug: slug, style_name: "Test" }
  end

  it "fails when no searches were performed" do
    stub_singleton(Search::ReasonedRunner, :call,
                   ->(**) { raise Search::NoSearchPerformedError, "no calls" }) do
      result = described_class.call(piece: nil, context: ctx)
      expect(result).to be_failed
    end
  end

  it "keeps subjects at or above the 3-shop minimum and rejects the rest" do
    spec, = build_test_spec(slug: "s-research")
    content = { "shops_sampled" => 8,
                "subjects" => [
                  { "subject" => "cottage", "recurs_across_shops" => 6 },
                  { "subject" => "moth", "recurs_across_shops" => 3 },
                  { "subject" => "black cat", "recurs_across_shops" => 2 }
                ] }
    stub_reasoned_runner(content: content) do
      result = described_class.call(piece: nil, context: ctx(spec.slug))
      expect(result).to be_ok
      rr = result.data[:subject_research]
      expect(rr[:recurring_subjects].map { |s| s["subject"] }).to contain_exactly("cottage", "moth")
      expect(rr[:rejected_subjects].map { |s| s["subject"] }).to eq(["black cat"])
    end
  end

  it "persists subject_research to the spec" do
    spec, = build_test_spec(slug: "s-persist")
    content = { "shops_sampled" => 8,
                "subjects" => [{ "subject" => "cottage", "recurs_across_shops" => 5 }] }
    stub_reasoned_runner(content: content) do
      described_class.call(piece: nil, context: ctx(spec.slug))
    end
    reloaded = KnowledgeBase::StyleSpec.load("s-persist")
    expect(reloaded.subject_research["recurring_subjects"]).to be_any
  end

  it "does not instruct the model to infer subjects from the style name" do
    tpl = Pipeline::KB_ROOT.join("prompts", "a_subject_research.md").read
    expect(tpl).to include("must not shape your")
    expect(tpl).to include("infer the subject from the style name")
  end
end

RSpec.describe Steps::TrackA::SceneResearch do
  def ctx(slug = "s")
    { style_slug: slug, style_name: "Test" }
  end

  it "keeps patterns at or above the 3-shop minimum and rejects the rest" do
    spec, = build_test_spec(slug: "sc-research")
    content = { "shops_sampled" => 8,
                "scene_patterns" => [
                  { "pattern_id" => "hidden_glimpsed_light", "narrative_structure" => "n",
                    "light_logic" => "l", "temporal_quality" => "t", "recurs_across_shops" => 6 },
                  { "pattern_id" => "figure_in_repose", "narrative_structure" => "n",
                    "light_logic" => "l", "temporal_quality" => "t", "recurs_across_shops" => 2 }
                ] }
    stub_reasoned_runner(content: content) do
      result = described_class.call(piece: nil, context: ctx(spec.slug))
      expect(result).to be_ok
      sr = result.data[:scene_research]
      expect(sr[:scene_patterns].map { |p| p["pattern_id"] }).to eq(["hidden_glimpsed_light"])
      expect(sr[:rejected_patterns].map { |p| p["pattern_id"] }).to eq(["figure_in_repose"])
    end
  end

  it "persists scene_research to the spec" do
    spec, = build_test_spec(slug: "sc-persist")
    content = { "shops_sampled" => 8,
                "scene_patterns" => [
                  { "pattern_id" => "p1", "narrative_structure" => "n", "light_logic" => "l",
                    "temporal_quality" => "t", "recurs_across_shops" => 5 }
                ] }
    stub_reasoned_runner(content: content) do
      described_class.call(piece: nil, context: ctx(spec.slug))
    end
    expect(KnowledgeBase::StyleSpec.load("sc-persist").scene_research["scene_patterns"]).to be_any
  end
end
