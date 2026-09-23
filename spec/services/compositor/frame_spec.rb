require "rails_helper"

RSpec.describe Compositor::Frame do
  def art(width = 400, height = 400)
    Vips::Image.black(width, height, bands: 3).copy(interpretation: :srgb)
  end

  def framed(piece)
    described_class.apply(art: art, piece: piece)
  end

  it "leaves the art untouched when the piece has no frame" do
    result = framed(build_piece)
    expect(result.width).to eq(400)
    expect(result.height).to eq(400)
  end

  it "adds a frame and mat around the art" do
    result = framed(build_piece(frame_material_category: "wood", matting_technique: "standard_single_mat"))
    expect(result.width).to be > 400
    expect(result.height).to be > 400
  end

  it "draws a narrower border when the technique has no mat" do
    no_mat = framed(build_piece(frame_material_category: "wood", matting_technique: "no_mat"))
    matted = framed(build_piece(frame_material_category: "wood", matting_technique: "standard_single_mat"))
    expect(no_mat.width).to be < matted.width
  end

  it "rounds the outer corners (adds an alpha band) for a rounded contour" do
    result = framed(build_piece(frame_material_category: "wood", frame_contour: "rounded",
                                matting_technique: "no_mat"))
    expect(result.bands).to eq(4)
  end

  it "draws no frame for a canvas print" do
    result = framed(build_piece(frame_material_category: "no_frame_canvas"))
    expect(result.width).to eq(400)
  end
end
