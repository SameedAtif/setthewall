require "rails_helper"

RSpec.describe "QA agents" do
  Result = Struct.new(:status, :data, :message, keyword_init: true) do
    def failed? = status == :failed
  end

  def run
    PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "test")
  end

  def result(data: {}, status: :awaiting_human)
    Result.new(status: status, data: data)
  end

  describe Agents::ResearchQa do
    it "passes the search floor when min_rounds_met" do
      f = described_class.call(run: run, step_id: "A0", result: result(data: { min_rounds_met: true, search_calls_made: 5 }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "blocks when the search floor is not met" do
      f = described_class.call(run: run, step_id: "A0", result: result(data: { min_rounds_met: false, search_calls_made: 2 }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "skips the search floor when min_rounds_met is absent" do
      f = described_class.call(run: run, step_id: "A0", result: result(data: {}), context: {})
      expect(f.map(&:claim).none? { |c| c.include?("floor") }).to be(true)
    end

    it "flags weak source independence" do
      images = [{ "attributing_sources" => ["a"] }]
      f = described_class.call(run: run, step_id: "A1", result: result(data: { candidates: { images: images } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory"))
    end

    it "passes strong source independence" do
      images = [{ "attributing_sources" => %w[a b] }]
      f = described_class.call(run: run, step_id: "A1", result: result(data: { candidates: { images: images } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "flags promotional framing language" do
      f = described_class.call(run: run, step_id: "A0", result: result(data: { survey_notes: "act now and get there early" }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory"))
    end

    it "blocks a fragmented A0 style" do
      f = described_class.call(run: run, step_id: "A0",
                               result: result(data: { findings: { breadth_assessment: "fragments_into_substyles",
                                                                 single_recommended_focus: "X" } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "blocks A1 when the set spans multiple mood clusters" do
      f = described_class.call(run: run, step_id: "A1",
                               result: result(data: { candidates: { mood_clusters_found: [{ "label" => "calm" }, { "label" => "bold" }] } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end
  end

  describe Agents::AxisQa do
    it "blocks a mixed A2 mood" do
      f = described_class.call(run: run, step_id: "A2",
                               result: result(data: { result: { mood: "mixed" } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "blocks an under-supported A2 mood" do
      f = described_class.call(run: run, step_id: "A2",
                               result: result(data: { result: { mood: "calm_ordered", markers_supporting_chosen_mood: 1,
                                                                clearly_supporting_images: 1 } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "passes a supported A2 mood" do
      f = described_class.call(run: run, step_id: "A2",
                               result: result(data: { result: { mood: "calm_ordered", markers_supporting_chosen_mood: 3,
                                                                clearly_supporting_images: 4 } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "blocks a failed A3 contour cross-check" do
      f = described_class.call(run: run, step_id: "A3",
                               result: result(data: { result: { contour_cross_check_passed: false,
                                                                predicted_contour: "flush_level_plane",
                                                                observed_contour: "outward_sloping" } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "passes a matching A3 contour" do
      f = described_class.call(run: run, step_id: "A3",
                               result: result(data: { result: { content_type: "minimalist_modern",
                                                                contour_cross_check_passed: true } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "advisories a mixed A4 framing" do
      f = described_class.call(run: run, step_id: "A4",
                               result: result(data: { result: { frame_form: "angular", consistency: "mixed" } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory"))
    end

    it "passes a consistent A4 framing" do
      f = described_class.call(run: run, step_id: "A4",
                               result: result(data: { result: { frame_form: "angular", consistency: "consistent" } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "blocks an ambiguous B3 room type" do
      f = described_class.call(run: run, step_id: "B3", result: result(data: { room_type: "ambiguous" }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "passes an unambiguous B3 room type" do
      f = described_class.call(run: run, step_id: "B3", result: result(data: { room_type: "seated_room" }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "blocks B6 when override is pending" do
      f = described_class.call(run: run, step_id: "B6", result: result(data: { override_pending: true, conflicts: [] }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "blocks B6 on cross-check conflicts" do
      f = described_class.call(run: run, step_id: "B6", result: result(data: { conflicts: ["x"], override_pending: false }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "passes a clean B6 colour role" do
      f = described_class.call(run: run, step_id: "B6",
                               result: result(data: { color_role: "line_only", conflicts: [], override_pending: false }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "advisories a borderline B1 read" do
      f = described_class.call(run: run, step_id: "B1", result: result(data: { wall_condition: "neutral", borderline: true }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory"))
    end

    it "passes an unambiguous B1 read" do
      f = described_class.call(run: run, step_id: "B1", result: result(data: { wall_condition: "neutral", borderline: false }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end
  end

  describe Agents::ListingQa do
    it "passes other steps" do
      f = described_class.call(run: run, step_id: "P3_2", result: result(data: {}), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "advisories a short title" do
      f = described_class.call(run: run, step_id: "P3_3", result: result(data: { title: "Art print" }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "advisory"))
    end

    it "passes a long title" do
      f = described_class.call(run: run, step_id: "P3_3",
                               result: result(data: { title: "Large Celestial Sun Moon Maximalist Wall Art Print" }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "blocks under-filled tags" do
      f = described_class.call(run: run, step_id: "P3_4", result: result(data: { tags: ["a"] }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "blocks a universal positioning claim" do
      f = described_class.call(run: run, step_id: "P3_6",
                               result: result(data: { description: { positioning_claim: "for everyone" } }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end

    it "advisories an inflated shipping ratio" do
      f = described_class.call(run: run, step_id: "P3_7", result: result(data: {}),
                               context: { item_price_usd: 10, shipping_price_usd: 6 })
      expect(f).to include(an_object_having_attributes(severity: "advisory"))
    end

    it "passes a shipping ratio within the heuristic band" do
      f = described_class.call(run: run, step_id: "P3_7", result: result(data: {}),
                               context: { item_price_usd: 10, shipping_price_usd: 2 })
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end
  end

  describe Agents::CustomerSafetyQa do
    it "passes clean copy" do
      f = described_class.call(run: run, step_id: "P3_6", result: result(data: { description: "A nice print" }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "pass"))
    end

    it "blocks safety claims" do
      f = described_class.call(run: run, step_id: "P3_6",
                               result: result(data: { description: "Hang with a sawtooth hanger rated 50 lbs" }), context: {})
      expect(f).to include(an_object_having_attributes(severity: "blocking"))
    end
  end
end
