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
end
