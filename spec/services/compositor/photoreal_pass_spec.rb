require "rails_helper"

RSpec.describe Compositor::PhotorealPass do
  def image_file
    path = Rails.root.join("tmp", "test_composites", "#{SecureRandom.hex(6)}.png")
    FileUtils.mkdir_p(path.dirname)
    Vips::Image.black(200, 150, bands: 3).write_to_file(path.to_s)
    track_kb_file(path)
    path.to_s
  end

  def empty_adapter
    instance_double(ImageGeneration::Adapter,
                    generate: ImageGeneration::Result.new(urls: [], provider: "manual",
                                                          model: "manual", estimated_cost_usd: 0.0,
                                                          raw_response: nil))
  end

  it "returns the refined image when the adapter produces one" do
    refined = image_file
    piece = build_piece(frame_material_category: "wood")
    stub_image_adapter(urls: [refined]) do
      expect(described_class.call(path: image_file, piece: piece)).to eq(refined)
    end
  end

  it "returns nil when the adapter produces no image (manual/offline)" do
    piece = build_piece(frame_material_category: "wood")
    allow(ImageGeneration::Adapter).to receive(:build).and_return(empty_adapter)
    expect(described_class.call(path: image_file, piece: piece)).to be_nil
  end

  it "returns nil when the provider raises" do
    piece = build_piece(frame_material_category: "wood")
    failing = instance_double(ImageGeneration::Adapter)
    allow(failing).to receive(:generate).and_raise(ImageGeneration::GenerationError, "boom")
    allow(ImageGeneration::Adapter).to receive(:build).and_return(failing)
    expect(described_class.call(path: image_file, piece: piece)).to be_nil
  end

  it "returns nil when the source image is missing" do
    piece = build_piece
    expect(described_class.call(path: "/no/such/file.png", piece: piece)).to be_nil
  end
end
