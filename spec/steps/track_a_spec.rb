require "rails_helper"

RSpec.describe Steps::TrackA do
  def validation_content
    { "breadth_assessment" => "single_coherent_style",
      "findings" => [],
      "cross_check_attempts" => ["Pinterest Trends search"],
      "single_recommended_focus" => "Ensō minimalist print",
      "recommendation_reasoning" => "best demand-to-competition ratio",
      "methodology_caveats" => "" }
  end

  def reference_set_content
    { "images" => [
      { "url" => "u1", "source_type" => "retailer", "source_name" => "s1",
        "attributing_sources" => %w[a b], "shot_type" => "in_situ" },
      { "url" => "u2", "source_type" => "retailer", "source_name" => "s1",
        "attributing_sources" => %w[a b], "shot_type" => "closeup" }
    ], "closeup_count" => 1, "total_count" => 2, "sources_used" => %w[a b] }
  end

  describe "ValidateStyle (A0)" do
    it "returns the research findings for human go/no-go" do
      stub_reasoned_runner(content: validation_content) do
        result = described_class::ValidateStyle.call(piece: nil, context: { style_name: "Japandi", style_slug: "japandi-v1" })
        expect(result).to be_awaiting_human
        expect(result.data[:findings]).to eq(validation_content)
      end
    end

    it "flags a fragmented style in the gate message" do
      fragmented = validation_content.merge(
        "breadth_assessment" => "fragments_into_substyles",
        "findings" => [{ "theme" => "a" }, { "theme" => "b" }],
        "single_recommended_focus" => "Ensō print"
      )
      stub_reasoned_runner(content: fragmented) do
        result = described_class::ValidateStyle.call(piece: nil, context: { style_name: "Japandi", style_slug: "japandi-v1" })
        expect(result).to be_awaiting_human
        expect(result.message).to include("FRAGMENTED")
        expect(result.message).to include("Japandi")
        expect(result.message).to include("2 distinct sub-themes")
      end
    end

    it "surfaces the cross-check attempt count in the gate message" do
      content = validation_content.merge("cross_check_attempts" => %w[route-a route-b route-c])
      stub_reasoned_runner(content: content) do
        result = described_class::ValidateStyle.call(piece: nil, context: { style_name: "Japandi", style_slug: "japandi-v1" })
        expect(result.message).to include("3 route(s)")
      end
    end

    it "records style_name_used as the narrowed pick when fragmented" do
      fragmented = validation_content.merge(
        "breadth_assessment" => "fragments_into_substyles",
        "single_recommended_focus" => "Ensō print"
      )
      stub_reasoned_runner(content: fragmented) do
        result = described_class::ValidateStyle.call(piece: nil, context: { style_name: "Japandi", style_slug: "japandi-v1" })
        expect(result.data[:style_name_used]).to eq("Ensō print")
      end
    end

    it "records style_name_used as the original name when coherent" do
      stub_reasoned_runner(content: validation_content) do
        result = described_class::ValidateStyle.call(piece: nil, context: { style_name: "Japandi", style_slug: "japandi-v1" })
        expect(result.data[:style_name_used]).to eq("Japandi")
      end
    end

    it "fails when no search was performed" do
      stub_singleton(Search::ReasonedRunner, :call, ->(**) { raise Search::NoSearchPerformedError }) do
        result = described_class::ValidateStyle.call(piece: nil, context: { style_name: "Japandi", style_slug: "japandi-v1" })
        expect(result).to be_failed
      end
    end
  end

  describe "BuildReferenceSet (A1)" do
    it "curates the reference set for human confirmation" do
      stub_reasoned_runner(content: reference_set_content) do
        result = described_class::BuildReferenceSet.call(piece: nil, context: { style_name: "Japandi" })
        expect(result).to be_awaiting_human
        expect(result.data[:issues]).to be_empty
      end
    end

    it "flags a weak set with too few close-ups" do
      weak = reference_set_content.merge("images" => [reference_set_content["images"].first])
      stub_reasoned_runner(content: weak) do
        result = described_class::BuildReferenceSet.call(piece: nil, context: { style_name: "Japandi" })
        expect(result).to be_awaiting_human
        expect(result.data[:issues]).not_to be_empty
      end
    end

    it "fails when no search was performed" do
      stub_singleton(Search::ReasonedRunner, :call, ->(**) { raise Search::NoSearchPerformedError }) do
        result = described_class::BuildReferenceSet.call(piece: nil, context: { style_name: "Japandi" })
        expect(result).to be_failed
      end
    end

    it "reports no images when the images field is a raw string" do
      stub_reasoned_runner(content: reference_set_content.merge("images" => "not an array")) do
        result = described_class::BuildReferenceSet.call(piece: nil, context: { style_name: "Japandi" })
        expect(result).to be_awaiting_human
        expect(result.data[:issues]).to include("no candidate images returned")
      end
    end

    it "drops image entries that are not hashes" do
      mixed = reference_set_content.merge("images" => ["oops", reference_set_content["images"].first])
      stub_reasoned_runner(content: mixed) do
        result = described_class::BuildReferenceSet.call(piece: nil, context: { style_name: "Japandi" })
        expect(result).to be_awaiting_human
        expect(result.data[:issues]).not_to include("no candidate images returned")
      end
    end
  end

  describe "SortMood (A2)" do
    let(:mood_content) do
      { "mood" => "calm_ordered",
        "marker_scores" => [], "markers_supporting_chosen_mood" => 2, "clearly_supporting_images" => 3 }
    end

    it "confirms a supported mood" do
      stub_llm(content: mood_content) do
        result = described_class::SortMood.call(piece: nil, context: { reference_images: %w[u1 u2] })
        expect(result).to be_awaiting_human
        expect(result.data[:recommended_action]).to eq("confirm")
      end
    end

    it "returns to A1 on a mixed scorecard" do
      stub_llm(content: mood_content.merge("mood" => "mixed")) do
        result = described_class::SortMood.call(piece: nil, context: { reference_images: %w[u1 u2] })
        expect(result.data[:recommended_action]).to eq("return_to_a1")
      end
    end

    it "returns to A1 on a weakly supported scorecard" do
      stub_llm(content: mood_content.merge("markers_supporting_chosen_mood" => 1, "clearly_supporting_images" => 1)) do
        result = described_class::SortMood.call(piece: nil, context: { reference_images: %w[u1 u2] })
        expect(result.data[:recommended_action]).to eq("return_to_a1")
      end
    end

    it "reports an empty response instead of crashing" do
      stub_llm(content: "") do
        result = described_class::SortMood.call(piece: nil, context: { reference_images: %w[u1 u2] })
        expect(result).to be_awaiting_human
        expect(result.message).to include("empty response")
        expect(result.data[:recommended_action]).to eq("return_to_a1")
      end
    end
  end

  describe "SortContentType (A3)" do
    def content(content_type: "minimalist_modern", passed: true)
      { "content_type" => content_type, "predicted_contour" => "flush_level_plane",
        "observed_contour" => "flush_level_plane", "contour_cross_check_passed" => passed, "reasoning" => "" }
    end

    it "confirms a content type whose contour matches" do
      stub_llm(content: content) do
        result = described_class::SortContentType.call(piece: nil, context: { reference_images: %w[u1 u2] })
        expect(result.data[:recommended_action]).to eq("confirm")
      end
    end

    it "flags a contour mismatch" do
      stub_llm(content: content(passed: false)) do
        result = described_class::SortContentType.call(piece: nil, context: { reference_images: %w[u1 u2] })
        expect(result.data[:recommended_action]).to eq("reconsider")
      end
    end

    it "reports an empty response instead of crashing" do
      stub_llm(content: "") do
        result = described_class::SortContentType.call(piece: nil, context: { reference_images: %w[u1 u2] })
        expect(result).to be_awaiting_human
        expect(result.message).to include("empty response")
        expect(result.data[:recommended_action]).to eq("reconsider")
      end
    end

    it "parses a fenced JSON response" do
      stub_llm(content: "```json\n#{content.to_json}\n```") do
        result = described_class::SortContentType.call(piece: nil, context: { reference_images: %w[u1 u2] })
        expect(result.data[:recommended_action]).to eq("confirm")
      end
    end
  end

  describe "SortFrameForm (A4)" do
    it "confirms a consistent frame form" do
      stub_llm(content: { "frame_form" => "angular", "consistency" => "consistent", "tiebreaker_used" => false, "reasoning" => "" }) do
        result = described_class::SortFrameForm.call(piece: nil, context: { reference_images: %w[u1 u2], mood: "calm_ordered" })
        expect(result).to be_awaiting_human
        expect(result.data[:note]).to include("consistent")
      end
    end

    it "notes the mood tiebreaker on a mixed reading" do
      stub_llm(content: { "frame_form" => "angular", "consistency" => "mixed", "tiebreaker_used" => true, "reasoning" => "" }) do
        result = described_class::SortFrameForm.call(piece: nil, context: { reference_images: %w[u1 u2], mood: "calm_ordered" })
        expect(result.data[:note]).to include("tiebreaker")
      end
    end

    it "reports an empty response instead of crashing" do
      stub_llm(content: "") do
        result = described_class::SortFrameForm.call(piece: nil, context: { reference_images: %w[u1 u2], mood: "calm_ordered" })
        expect(result).to be_awaiting_human
        expect(result.message).to include("empty response")
      end
    end
  end

  describe "LockStyleEntry (A5)" do
    let(:context) do
      { style_slug: "lock-style", style_name: "T", mood: "calm_ordered",
        content_type: "minimalist_modern", frame_form: "angular", confirmed: false }
    end

    it "asks for confirmation before locking" do
      result = described_class::LockStyleEntry.call(piece: nil, context: context)
      expect(result).to be_awaiting_human
    end

    it "writes the spec when confirmed" do
      result = described_class::LockStyleEntry.call(piece: nil, context: context.merge(confirmed: true))
      track_kb_file(Pipeline::KB_ROOT.join("style_specs/lock-style.yml"))
      expect(result).to be_ok
      expect(KnowledgeBase::StyleSpec.load("lock-style").style_level[:mood]).to eq("calm_ordered")
    end

    it "refuses to lock an unclassifiable mood" do
      result = described_class::LockStyleEntry.call(
        piece: nil,
        context: context.merge(mood: "mixed", confirmed: true)
      )
      expect(result).to be_failed
      expect(result.message).to include("mood=\"mixed\"")
    end
  end
end
