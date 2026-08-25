require "rails_helper"

RSpec.describe Steps::TrackC::GenerateArt do
  it "fails when candidate_count is below one" do
    piece = build_piece
    piece.save!
    result = described_class.call(piece: piece, context: { candidate_count: 0 })
    expect(result).to be_failed
  end

  it "pauses for the manual adapter" do
    piece = build_piece
    piece.save!
    stub_llm(content: { "image_generation_prompt" => "p", "axis_contributions" => [], "negative_prompt" => "" }) do
      stub_singleton(ImageGeneration::Adapter, :build, -> { ImageGeneration::ManualAdapter.new }) do
        result = described_class.call(piece: piece, context: { candidate_count: 2 })
        expect(result).to be_awaiting_human
        expect(result.data[:prompt_file]).to be_present
      end
    end
  end
end

RSpec.describe Steps::TrackA::BuildReferenceSet do
  it "flags an empty candidate set" do
    stub_reasoned_runner(content: { "images" => [], "closeup_count" => 0, "total_count" => 0, "sources_used" => [] }) do
      result = described_class.call(piece: nil, context: { style_name: "Japandi" })
      expect(result.data[:issues]).to include("no candidate images returned")
    end
  end
end

RSpec.describe Steps::Phase3::DraftTitle do
  it "pauses for a title that fails validation" do
    piece = build_piece
    piece.save!
    stub_llm(content: { "title" => "Beautiful stunning print", "first_six_words" => "Beautiful stunning print", "occasion_word_included" => false, "reasoning" => "" }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_awaiting_human
      expect(result.data[:errors]).not_to be_empty
    end
  end
end

RSpec.describe Steps::Phase3::PublishAndLog do
  it "fails when there are no photos" do
    piece = create(:piece_record, listing_title: "t", listing_tags: ["x"],
                                  listing_attributes: { "rp" => "x" }, listing_description: "d", listing_category: "1")
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_failed
  end

  it "fails when Etsy raises" do
    piece = create(:piece_record, listing_title: "t", listing_tags: ["x"],
                                  listing_attributes: { "rp" => "x" }, listing_description: "d",
                                  listing_category: "1", photos: { "studio" => "s" })
    adapter = double("adapter")
    allow(adapter).to receive(:create_listing).and_raise(Etsy::ApiError, "boom")
    stub_singleton(Etsy::Adapter, :build, -> { adapter }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_failed
    end
  end
end

RSpec.describe Steps::Phase3::ShippingAndReturns do
  it "warns on inflated shipping" do
    piece = create(:piece_record)
    result = described_class.call(piece: piece, context: {
      return_policy: "30 days", shipping_price_usd: 50, item_price_usd: 100, confirmed: true
    })
    expect(result).to be_ok
    expect(result.data[:warnings]).not_to be_empty
  end
end
