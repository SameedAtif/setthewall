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
      "survey_notes" => "sparse"
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

  it "returns candidates for the human to pick from" do
    stub_reasoned_runner(content: ideation_content) do
      result = described_class.call(piece: nil, context: {})
      expect(result).to be_awaiting_human
      expect(result.data[:candidates].size).to eq(2)
      expect(result.data[:weak_candidates]).to eq(["Weak candidate"])
      expect(result.message).to include("Pick ONE")
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

  it "fails when no search was performed" do
    stub_singleton(Search::ReasonedRunner, :call, ->(**) { raise Search::NoSearchPerformedError }) do
      result = described_class.call(piece: nil, context: {})
      expect(result).to be_failed
    end
  end
end
