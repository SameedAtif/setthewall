require "rails_helper"

RSpec.describe KnowledgeBase::SceneSpecWriter do
  def valid_axes
    { wall_condition: "neutral", furniture_weight: "light", room_type: "seated_room",
      room_shape: "none", space_math: "single" }
  end

  def locked_spec
    slug = "test-scene-writer-#{SecureRandom.hex(4)}"
    KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
      slug: slug, name: "T", mood: "calm_ordered",
      content_type: "minimalist_modern", frame_form: "angular",
      production_model: { "fulfillment_type" => "physical", "piece_count" => 1 }
    )
    track_kb_file(Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml"))
    slug
  end

  it "refuses before the style level is locked" do
    expect do
      described_class.write_scene_axes(
        style_slug: "nonexistent-#{SecureRandom.hex(4)}", scene_id: "s1", scene_name: "S1",
        template_ref: "x.yml", axes: valid_axes
      )
    end.to raise_error(KnowledgeBase::IncompleteSpecError)
  end

  it "writes scene axes and produces a valid spec" do
    slug = locked_spec
    scene = described_class.write_scene_axes(
      style_slug: slug, scene_id: "s1", scene_name: "S1",
      template_ref: "scene_templates/s1.yml", axes: valid_axes
    )

    expect(scene.id).to eq("s1")
    expect(scene.wall_condition).to eq("neutral")
    expect(scene.room_type).to eq("seated_room")
    expect { KnowledgeBase::StyleSpec.load(slug).validate! }.not_to raise_error
  end

  it "rejects an invalid axis value" do
    slug = locked_spec
    expect do
      described_class.write_scene_axes(
        style_slug: slug, scene_id: "s2", scene_name: "S2",
        template_ref: "x.yml", axes: valid_axes.merge(wall_condition: "invalid")
      )
    end.to raise_error(KnowledgeBase::IncompleteSpecError)
  end

  it "rejects blank axes" do
    slug = locked_spec
    expect do
      described_class.write_scene_axes(
        style_slug: slug, scene_id: "s3", scene_name: "S3",
        template_ref: "x.yml", axes: valid_axes.merge(room_type: nil)
      )
    end.to raise_error(KnowledgeBase::IncompleteSpecError)
  end
end
