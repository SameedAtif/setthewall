require "rails_helper"

RSpec.describe Steps::Phase3::GeneratePhotoTypes do
  it "confirms when all required photos are present" do
    piece = create(:piece_record, composite_url: "http://comp")
    result = described_class.call(piece: piece, context: { provided_urls: { "studio" => "s", "detail" => "d" } })
    expect(result).to be_awaiting_human
    expect(piece.reload.photos["studio"]).to eq("s")
  end

  it "generates the missing photo types" do
    piece = create(:piece_record, composite_url: "http://comp")
    stub_image_adapter(urls: ["http://gen.png"]) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_awaiting_human
      expect(result.data[:generated_types]).to include("studio", "detail")
    end
  end

  it "completes when confirmed" do
    piece = create(:piece_record, composite_url: "http://comp")
    result = described_class.call(piece: piece, context: { confirmed: true })
    expect(result).to be_ok
  end

  it "raises for an unexpected photo type" do
    step = described_class.new(piece: create(:piece_record), context: {})
    expect { step.send(:build_photo_prompt, "scale") }.to raise_error(/Unexpected photo type/)
  end
end

RSpec.describe Steps::Phase3::SelectAndOrderPhotos do
  it "fails when there are no photos" do
    result = described_class.call(piece: create(:piece_record), context: {})
    expect(result).to be_failed
  end

  it "recommends a hero photo" do
    piece = create(:piece_record, photos: { "studio" => "s", "lifestyle" => "l" })
    stub_llm(content: { "recommended_hero" => "s", "reasoning" => "clear", "ordering" => ["s", "l"], "photo_count" => 2 }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_awaiting_human
    end
  end

  it "completes when confirmed" do
    piece = create(:piece_record, photos: { "studio" => "s" })
    result = described_class.call(piece: piece, context: { confirmed: true })
    expect(result).to be_ok
  end
end

RSpec.describe Steps::Phase3::WriteDescription do
  let(:good) do
    { "essential_info_block" => "8x10", "engagement_block" => "For calm spaces.",
      "positioning_claim" => "For someone building a calm space.",
      "tag_phrases_used" => [], "full_description" => "8x10 print" }
  end

  def piece_with(**attrs)
    piece = build_piece(**attrs)
    piece.save!
    piece
  end

  it "flags keyword stuffing" do
    piece = piece_with(listing_tags: ["minimalist wall art"])
    content = good.merge("full_description" => "minimalist wall art " * 5)
    stub_llm(content: content) do
      result = described_class.call(piece: piece, context: { positioning_target: "x" })
      expect(result).to be_awaiting_human
      expect(result.data[:violations]).not_to be_empty
    end
  end

  it "flags a generic positioning claim" do
    piece = piece_with
    stub_llm(content: good.merge("positioning_claim" => "for everyone who loves art")) do
      result = described_class.call(piece: piece, context: { positioning_target: "x" })
      expect(result).to be_awaiting_human
    end
  end

  it "persists a good description and pauses for tone confirmation" do
    piece = piece_with
    stub_llm(content: good) do
      result = described_class.call(piece: piece, context: { positioning_target: "x" })
      expect(result).to be_awaiting_human
      expect(piece.reload.listing_description).to eq("8x10 print")
    end
  end

  it "completes when confirmed" do
    piece = piece_with(listing_description: "d")
    result = described_class.call(piece: piece, context: { confirmed: true })
    expect(result).to be_ok
  end
end

RSpec.describe Steps::Phase3::PublishAndLog do
  let(:ready_attrs) do
    { listing_title: "t", listing_tags: ["x"], listing_attributes: { "return_policy" => "x" },
      listing_description: "d", listing_category: "1", photos: { "studio" => "s" } }
  end

  it "fails when listing fields are missing" do
    result = described_class.call(piece: create(:piece_record, photos: { "studio" => "s" }), context: {})
    expect(result).to be_failed
  end

  it "pauses for the manual adapter" do
    piece = create(:piece_record, **ready_attrs)
    stub_singleton(Etsy::Adapter, :build, -> { Etsy::ManualAdapter.new }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_awaiting_human
    end
  end

  it "publishes and logs a baseline snapshot" do
    piece = create(:piece_record, **ready_attrs)
    stub_etsy_adapter(listing_id: "9999") do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_ok
      expect(piece.reload.etsy_listing_id).to eq("9999")
      expect(piece.performance_snapshots.count).to eq(1)
    end
  end
end

RSpec.describe Steps::Phase3::PullInputs do
  it "fails when Phase 2 outputs are missing" do
    piece = create(:piece_record)
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_failed
    expect(result.data[:missing_fields]).not_to be_empty
  end

  it "pulls inputs from a completed Phase 2 piece" do
    spec, = build_test_spec
    piece = create(:piece_record, style_spec_slug: spec.slug, scene_spec_id: "s1",
                                  chosen_url: "u", composite_url: "c", frame_material_category: "metal",
                                  frame_contour: "flush_level_plane", matting_technique: "standard_single_mat",
                                  color_role_confirmed: "line_only")
    piece.apply_spec!(spec, spec.scene("s1"))
    piece.save!

    result = described_class.call(piece: piece, context: {})
    expect(result).to be_ok
    expect(result.data[:style_summary][:color_role]).to eq("line_only")
  end
end

RSpec.describe Steps::Phase3::FillTags do
  def valid_tags
    angles = %w[style_descriptor room_or_space_use gift_or_occasion alternate_use]
    tags = angles.flat_map.with_index do |angle, ai|
      (ai == 3 ? 4 : 3).times.map do |j|
        { "tag" => "#{angle.tr('_', ' ')} #{j} wall art", "angle" => angle, "breadth" => "specific_long_tail" }
      end
    end
    { "tags" => tags, "distinct_angles_covered" => 4, "missing_angles" => [] }
  end

  it "flags a wrong tag count" do
    piece = build_piece
    piece.save!
    stub_llm(content: { "tags" => [], "distinct_angles_covered" => 0, "missing_angles" => [] }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_awaiting_human
    end
  end

  it "flags near-duplicate tags" do
    piece = build_piece
    piece.save!
    tags = Array.new(13) { |i| { "tag" => "same tag #{i % 2}", "angle" => "style_descriptor", "breadth" => "broad" } }
    stub_llm(content: { "tags" => tags, "distinct_angles_covered" => 1, "missing_angles" => [] }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_awaiting_human
    end
  end

  it "persists valid tags" do
    piece = build_piece
    piece.save!
    stub_llm(content: valid_tags) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_ok
      expect(piece.reload.listing_tags.size).to eq(13)
    end
  end
end
