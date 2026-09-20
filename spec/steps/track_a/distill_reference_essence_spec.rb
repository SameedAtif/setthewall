require "rails_helper"

RSpec.describe Steps::TrackA::DistillReferenceEssence do
  it "fails without reference images" do
    result = described_class.call(piece: nil, context: { reference_images: [] })

    expect(result).to be_failed
  end

  it "distils a typed essence from the reference images" do
    ref = build_art_image.to_s
    content = {
      "medium" => "flat printed poster",
      "palette" => "warm bone through ash grey",
      "surface_treatment" => "ton-sur-ton trowel ridges",
      "motif_vocabulary" => ["nested wavy grooves", "soft layered edges"],
      "styling" => "thin frame on a neutral wall",
      "field_evidence" => [{ "field" => "palette", "image_indices" => [1] }]
    }

    stub_llm(content: content) do
      result = described_class.call(piece: nil, context: { reference_images: [ref] })

      expect(result).to be_ok
      expect(result.data[:essence]["palette"]).to eq("warm bone through ash grey")
      expect(result.data[:essence]["motif_vocabulary"]).to eq(["nested wavy grooves", "soft layered edges"])
      expect(result.data[:image_count]).to eq(1)
    end
  end

  it "derives color_role by majority vote and carries palette_character" do
    ref = build_art_image.to_s
    content = {
      "palette" => "warm",
      "palette_character" => "warm-neutral tonal range, no saturated hue",
      "image_color_roles" => [
        { "index" => 1, "color_role" => "saturator" },
        { "index" => 2, "color_role" => "saturator" },
        { "index" => 3, "color_role" => "color_burst" }
      ]
    }

    stub_llm(content: content) do
      result = described_class.call(piece: nil, context: { reference_images: [ref] })
      essence = result.data[:essence]
      expect(essence["color_role"]).to eq("saturator")
      expect(essence["color_role_ambiguous"]).to be(false)
      expect(essence["color_role_tally"]).to eq("saturator" => 2, "color_burst" => 1)
      expect(essence["palette_character"]).to eq("warm-neutral tonal range, no saturated hue")
    end
  end

  it "flags an ambiguous color_role for the human when the vote ties" do
    ref = build_art_image.to_s
    content = {
      "palette" => "mixed",
      "image_color_roles" => [
        { "index" => 1, "color_role" => "saturator" },
        { "index" => 2, "color_role" => "color_burst" }
      ]
    }

    stub_llm(content: content) do
      result = described_class.call(piece: nil, context: { reference_images: [ref] })
      expect(result.data[:essence]["color_role"]).to be_nil
      expect(result.data[:essence]["color_role_ambiguous"]).to be(true)
      expect(result.message).to match(/AMBIGUOUS/)
    end
  end

  it "excludes outlier images from the color_role vote" do
    ref = build_art_image.to_s
    content = {
      "palette" => "warm",
      "outlier_indices" => [2],
      "image_color_roles" => [
        { "index" => 1, "color_role" => "saturator" },
        { "index" => 2, "color_role" => "color_burst" }
      ]
    }

    stub_llm(content: content) do
      result = described_class.call(piece: nil, context: { reference_images: [ref] })
      expect(result.data[:essence]["color_role"]).to eq("saturator")
    end
  end
end
