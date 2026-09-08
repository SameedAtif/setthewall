require "rails_helper"

RSpec.describe Steps::Phase2::LoadStyleSpec do
  it "loads and validates a spec" do
    spec, = build_test_spec
    result = described_class.call(piece: nil, context: { style_slug: spec.slug })
    expect(result).to be_ok
    expect(result.data[:scenes]).to include("s1")
  end

  it "fails on an incomplete spec" do
    result = described_class.call(piece: nil, context: { style_slug: "nonexistent-#{SecureRandom.hex(4)}" })
    expect(result).to be_failed
  end

  it "blocks when the piece's fulfillment_type contradicts the spec" do
    spec, = build_test_spec
    piece = create(:piece_record, style_spec_slug: spec.slug, scene_spec_id: "s1",
                                  fulfillment_type: "digital")
    result = described_class.call(piece: piece, context: { style_slug: spec.slug })
    expect(result).to be_failed
    expect(result.message).to include("fulfillment_type")
  end

  it "passes when the piece's fulfillment_type matches the spec" do
    spec, = build_test_spec
    piece = create(:piece_record, style_spec_slug: spec.slug, scene_spec_id: "s1",
                                  fulfillment_type: "physical")
    result = described_class.call(piece: piece, context: { style_slug: spec.slug })
    expect(result).to be_ok
  end
end

RSpec.describe Steps::Phase2::AssignFrame do
  def assign(mood:, content_type:, palette: "neutral", context: {})
    piece = build_piece(mood: mood, content_type: content_type)
    piece.save!
    described_class.call(piece: piece, context: { palette: palette }.merge(context))
    piece
  end

  it "assigns metal for minimalist_modern" do
    piece = assign(mood: "calm_ordered", content_type: "minimalist_modern")
    expect(piece.frame_material_category).to eq("metal")
    expect(piece.frame_material_finish).to eq("black_metal")
  end

  it "assigns ornate_carved for bold detailed" do
    piece = assign(mood: "bold_active", content_type: "detailed_representational")
    expect(piece.frame_material_category).to eq("ornate_carved")
  end

  it "assigns wood for calm non-minimalist" do
    piece = assign(mood: "calm_ordered", content_type: "portrait_still_life")
    expect(piece.frame_material_category).to eq("wood")
  end

  it "defaults to metal for bold non-representational" do
    piece = assign(mood: "bold_active", content_type: "minimalist_modern")
    expect(piece.frame_material_category).to eq("metal")
    expect(piece.frame_material_finish).to eq("follows_accent_color")
  end

  it "picks gold for a warm calm palette" do
    piece = assign(mood: "calm_ordered", content_type: "minimalist_modern", palette: "warm")
    expect(piece.frame_material_finish).to eq("gold")
  end

  it "picks silver for a cool palette" do
    piece = assign(mood: "calm_ordered", content_type: "minimalist_modern", palette: "cool")
    expect(piece.frame_material_finish).to eq("silver_aluminum")
  end
end

RSpec.describe Steps::Phase2::WeightBalance do
  it "fails on heavy art over dark furniture" do
    piece = build_piece
    piece.furniture_weight = "dark"
    piece.frame_material_category = "ornate_carved"
    piece.save!
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_awaiting_human
  end

  it "passes light furniture" do
    piece = build_piece
    piece.save!
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_ok
    expect(piece.reload.weight_balance_pass).to be(true)
  end
end

RSpec.describe Steps::Phase2::UnifyByTheme do
  it "skips for a single piece" do
    piece = build_piece(piece_count: 1)
    piece.save!
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_ok
    expect(result.data[:skipped]).to be(true)
  end

  it "fails the set when checks fail" do
    piece = build_piece(piece_count: 3, finalist_urls: %w[a b], chosen_url: "a")
    piece.save!
    content = { "reads_as_one_collection" => false, "shared_thread" => "x",
                "checks" => [], "fails_count" => 2, "borderlines_count" => 0 }
    stub_llm(content: content) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_awaiting_human
    end
  end

  it "passes a unified set" do
    piece = build_piece(piece_count: 3, finalist_urls: %w[a b], chosen_url: "a")
    piece.save!
    content = { "reads_as_one_collection" => true, "shared_thread" => "x",
                "checks" => [], "fails_count" => 0, "borderlines_count" => 0 }
    stub_llm(content: content) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_ok
    end
  end
end
