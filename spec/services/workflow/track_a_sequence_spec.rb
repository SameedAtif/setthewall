require "rails_helper"

RSpec.describe Workflow::TrackASequence do
  describe ".next_step_for" do
    it "starts at A_IDEATE" do
      expect(described_class.next_step_for({ "last_completed_step" => nil })).to eq("A_IDEATE")
    end

    it "advances through the sequence" do
      expect(described_class.next_step_for({ "last_completed_step" => "A0" })).to eq("A1")
      expect(described_class.next_step_for({ "last_completed_step" => "A4" })).to eq("A5")
    end

    it "raises on an unknown last step" do
      expect { described_class.next_step_for({ "last_completed_step" => "BOGUS" }) }
        .to raise_error(ArgumentError, /BOGUS/)
    end
  end

  describe ".build_context" do
    it "auto-fills A1's style_name from A0's style_name_used" do
      session = { "decisions" => { "A0" => { "style_name_used" => "Ensō Ink" } } }
      expect(described_class.build_context("A1", session, {})).to eq(style_name: "Ensō Ink")
    end

    it "lets fresh context override the session value" do
      session = { "decisions" => { "A0" => { "style_name_used" => "Ensō Ink" } } }
      ctx = described_class.build_context("A1", session, { style_name: "Override" })
      expect(ctx[:style_name]).to eq("Override")
    end

    it "auto-fills A4's mood from A2 and reference_images from A3" do
      session = { "decisions" => {
        "A2" => { "mood" => "calm_ordered" },
        "A3" => { "reference_images" => %w[u1 u2] }
      } }
      ctx = described_class.build_context("A4", session, {})
      expect(ctx[:mood]).to eq("calm_ordered")
      expect(ctx[:reference_images]).to eq(%w[u1 u2])
    end

    it "never auto-fills A5's confirmed, even from a stray session value" do
      session = { "decisions" => { "A4" => { "confirmed" => true } } }
      ctx = described_class.build_context("A5", session, {})
      expect(ctx.key?(:confirmed)).to be(false)
    end
  end

  describe ".missing_required" do
    it "flags A0's fresh keys when nothing supplies them" do
      expect(described_class.missing_required("A0", {}).sort).to eq(%i[style_name style_slug])
    end

    it "returns empty when every key is supplied" do
      ctx = { style_name: "Japandi", style_slug: "japandi-v1" }
      expect(described_class.missing_required("A0", ctx)).to eq([])
    end
  end
end
