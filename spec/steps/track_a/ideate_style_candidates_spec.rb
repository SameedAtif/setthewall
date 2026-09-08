require "rails_helper"

RSpec.describe Steps::TrackA::IdeateStyleCandidates do
  def ideation_content
    {
      "candidates" => [
        { "name" => "Warm minimalist textured abstract", "trend_signal" => "rising",
          "independent_source_count" => 3,
          "sources" => [{ "source_name" => "A", "promotional_language_detected" => false }],
          "competition_read" => "medium" },
        { "name" => "Weak candidate", "trend_signal" => "x", "independent_source_count" => 1,
          "sources" => [], "competition_read" => "unknown" }
      ],
      "survey_notes" => "sparse",
      "recommended_focus" => "Warm minimalist textured abstract"
    }
  end

  def capture_runner_call
    captured = nil
    stub_singleton(Search::ReasonedRunner, :call,
                   ->(**kwargs) { captured = kwargs; { content: ideation_content, search_calls_made: 5, transcript: [] } }) do
      yield
    end
    captured
  end

  it "returns candidates with a recommended focus for the speculative run to pick" do
    stub_reasoned_runner(content: ideation_content) do
      result = described_class.call(piece: nil, context: {})
      expect(result).to be_awaiting_human
      expect(result.data[:candidates].size).to eq(2)
      expect(result.data[:weak_candidates]).to eq(["Weak candidate"])
      expect(result.data[:recommended_focus]).to eq("Warm minimalist textured abstract")
      expect(result.message).to include("Recommended focus")
    end
  end

  it "caps the candidate count at the maximum" do
    captured = capture_runner_call { described_class.call(piece: nil, context: { candidate_count: 99 }) }
    expect(captured[:question]).to include("surface 8")
  end

  it "uses the default count when none is given" do
    captured = capture_runner_call { described_class.call(piece: nil, context: {}) }
    expect(captured[:question]).to include("surface 5")
  end

  it "includes the direction steer when provided" do
    captured = capture_runner_call { described_class.call(piece: nil, context: { direction: "bold and colorful" }) }
    expect(captured[:question]).to include("bold and colorful")
  end

  it "forwards the on_progress callback to the runner" do
    callback = ->(_message) { }
    captured = capture_runner_call { described_class.call(piece: nil, context: { on_progress: callback }) }
    expect(captured[:on_progress]).to eq(callback)
  end

  it "fails when no search was performed" do
    stub_singleton(Search::ReasonedRunner, :call, ->(**) { raise Search::NoSearchPerformedError }) do
      result = described_class.call(piece: nil, context: {})
      expect(result).to be_failed
    end
  end

  it "treats a non-array candidates field as no candidates" do
    stub_reasoned_runner(content: { "candidates" => "not an array", "survey_notes" => "x" }) do
      result = described_class.call(piece: nil, context: {})
      expect(result).to be_awaiting_human
      expect(result.data[:candidates]).to eq([])
      expect(result.data[:weak_candidates]).to eq([])
    end
  end

  it "drops candidate entries that are not hashes" do
    content = { "candidates" => ["oops", { "name" => "Good", "independent_source_count" => 3,
                                            "sources" => [], "competition_read" => "medium" }],
                "survey_notes" => "x" }
    stub_reasoned_runner(content: content) do
      result = described_class.call(piece: nil, context: {})
      expect(result.data[:candidates].map { |c| c["name"] }).to eq(["Good"])
    end
  end

  it "does not crash when the whole content is a raw string" do
    stub_reasoned_runner(content: "freeform prose") do
      result = described_class.call(piece: nil, context: {})
      expect(result).to be_awaiting_human
      expect(result.data[:candidates]).to eq([])
    end
  end
end
