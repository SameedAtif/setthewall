require "rails_helper"

RSpec.describe Steps::Phase2::MeasureScene do
  it "pauses on location suitability issues" do
    piece = build_piece
    piece.save!
    allow_any_instance_of(described_class).to receive(:check_location_suitability).and_return(["humid room"])
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_awaiting_human
  end
end

RSpec.describe Steps::Phase2::NookFit do
  it "fits a group into a nook" do
    piece = build_piece
    piece.chosen_url = "a"
    piece.save!
    result = described_class.call(piece: piece, context: { piece_count: 2, anchor_url: "anchor" })
    expect(result).to be_ok
    expect(piece.reload.anchor_piece_ref).to eq("anchor")
  end
end

RSpec.describe Steps::Phase2::SplitWallZoning do
  it "pauses for zones when none are provided" do
    piece = build_piece
    piece.save!
    result = described_class.call(piece: piece, context: { split_technique: "chair_rail" })
    expect(result).to be_awaiting_human
  end
end

RSpec.describe Steps::Phase2::SurfaceDisplay do
  it "pauses on a flat multi-piece display" do
    piece = build_piece
    piece.save!
    result = described_class.call(piece: piece, context: { piece_count: 2, heights_used: [1, 1], surface_type: "mantel" })
    expect(result).to be_awaiting_human
  end
end

RSpec.describe Steps::Phase2::SetGroupingAndCount do
  it "pauses for the set specification when piece_count is missing" do
    piece = build_piece
    piece.save!
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_awaiting_human
  end

  it "rejects stair_stepping off a staircase" do
    piece = build_piece
    piece.save!
    result = described_class.call(piece: piece, context: { piece_count: 3, base_form: "stair_stepping" })
    expect(result).to be_failed
  end
end

RSpec.describe Steps::Phase2::Composite do
  it "fails on a compositor error" do
    piece = build_piece
    piece.save!
    allow(Compositor::Runner).to receive(:call).and_raise(Compositor::TemplateError, "boom")
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_failed
    expect(result.message).to include("Compositor failed")
  end

  it "fails on a coverage-cap violation" do
    piece = build_piece
    piece.save!
    result_obj = Compositor::Result.new(output_path: "/tmp/x.png", measurements: { coverage_fraction: 0.8 })
    allow(Compositor::Runner).to receive(:call).and_return(result_obj)
    result = described_class.call(piece: piece, context: {})
    expect(result).to be_failed
    expect(result.message).to include("Coverage cap")
  end
end
