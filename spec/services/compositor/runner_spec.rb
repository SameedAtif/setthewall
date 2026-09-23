require "rails_helper"

RSpec.describe Compositor::Runner do
  def write_template(scene_id, measurements)
    assets = Pipeline::KB_ROOT.join("scene_templates/assets")
    FileUtils.mkdir_p(assets.to_s)
    scene_img = assets.join("#{scene_id}.png")
    Vips::Image.black(2400, 1600).write_to_file(scene_img.to_s)
    track_kb_file(scene_img)

    tpl = Pipeline::KB_ROOT.join("scene_templates", "#{scene_id}.yml")
    body = { "id" => scene_id, "name" => "T",
             "image_path" => "scene_templates/assets/#{scene_id}.png" }
    body["measurements"] = measurements if measurements
    tpl.write(body.to_yaml)
    track_kb_file(tpl)
    tpl
  end

  def piece_for(scene_id, room_type: "seated_room")
    piece = build_piece(scene_id: scene_id, chosen_url: build_art_image)
    piece.room_type = room_type
    piece.save!
    piece
  end

  def portrait_art_image(w = 100, h = 200)
    path = Rails.root.join("tmp", "test_art", "#{SecureRandom.hex(8)}.png")
    FileUtils.mkdir_p(File.dirname(path))
    Vips::Image.black(w, h).write_to_file(path.to_s)
    track_kb_file(path)
    path
  end

  let(:full_measurements) do
    { "image_width_px" => 2400, "image_height_px" => 1600, "pixels_per_inch" => 24,
      "furniture_top_edge_y_px" => 900, "wall_zone" => { "x" => 200, "y" => 100, "width" => 2000, "height" => 800 },
      "seated_eye_level_y_px" => 850, "standing_eye_level_y_px" => 720, "furniture_width_px" => 800 }
  end

  it "raises when the template file is missing" do
    piece = piece_for("missing-template")
    expect { described_class.call(piece: piece) }.to raise_error(Compositor::TemplateError)
  end

  it "raises when the template has no measurements" do
    write_template("no-meas", nil)
    piece = piece_for("no-meas")
    expect { described_class.call(piece: piece) }.to raise_error(Compositor::TemplateError, /measurements/)
  end

  it "raises when the anchor key is missing" do
    write_template("no-anchor", full_measurements.reject { |k, _| k == "furniture_top_edge_y_px" })
    piece = piece_for("no-anchor")
    expect { described_class.call(piece: piece) }.to raise_error(Compositor::TemplateError)
  end

  it "composites a seated-room piece" do
    write_template("seated", full_measurements)
    piece = piece_for("seated")
    result = described_class.call(piece: piece)
    expect(File.exist?(result.output_path)).to be(true)
    expect(result.measurements[:coverage_fraction]).to be < 0.6667
  ensure
    File.delete(result&.output_path) rescue nil
  end

  it "composites a hallway piece without furniture" do
    write_template("hallway", full_measurements.reject { |k, _| %w[furniture_width_px furniture_top_edge_y_px].include?(k) })
    piece = piece_for("hallway", room_type: "hallway")
    result = described_class.call(piece: piece)
    expect(File.exist?(result.output_path)).to be(true)
  ensure
    File.delete(result&.output_path) rescue nil
  end

  it "raises when declared image dimensions mismatch the actual image" do
    write_template("mismatch", full_measurements.merge("image_width_px" => 1000, "image_height_px" => 1000))
    piece = piece_for("mismatch")
    expect { described_class.call(piece: piece) }
      .to raise_error(Compositor::TemplateError, /declares 1000x1000/)
  end

  it "bounds a tall portrait art to the wall zone (no ceiling/sofa overflow)" do
    write_template("tall", full_measurements)
    piece = build_piece(scene_id: "tall", chosen_url: portrait_art_image(100, 200))
    piece.room_type = "seated_room"
    piece.save!
    result = described_class.call(piece: piece)
    m = result.measurements
    zone = full_measurements["wall_zone"]
    expect(m[:art_height_px]).to be <= zone["height"]
    expect(m[:x_px]).to be >= zone["x"]
    expect(m[:y_px]).to be >= zone["y"]
    expect(m[:x_px] + m[:art_width_px]).to be <= zone["x"] + zone["width"]
    expect(m[:y_px] + m[:art_height_px]).to be <= zone["y"] + zone["height"]
  ensure
    File.delete(result&.output_path) rescue nil
  end

  it "emits computed placement geometry for QA" do
    write_template("seated-geo", full_measurements)
    piece = piece_for("seated-geo")
    result = described_class.call(piece: piece)
    m = result.measurements
    expect(m[:furniture_width_px]).to eq(800)
    expect(m[:group_width_px]).to be_positive
    expect(m[:furniture_gap_px]).to be_positive
    expect(m[:drop_applied_inches]).to be_within(0.01).of(3.5)
  ensure
    File.delete(result&.output_path) rescue nil
  end
end
