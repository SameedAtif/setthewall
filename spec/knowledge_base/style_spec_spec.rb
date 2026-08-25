require "rails_helper"

RSpec.describe KnowledgeBase::StyleSpec do
  def with_spec(raw)
    slug = "test-spec-#{SecureRandom.hex(4)}"
    raw = raw.sub("__SLUG__", slug)
    path = Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml")
    path.write(raw)
    track_kb_file(path)
    yield slug
  end

  it "loads a valid style spec" do
    raw = <<~YAML
      slug: __SLUG__
      name: "Test"
      style_level:
        mood: calm_ordered
        content_type: minimalist_modern
        frame_form: angular
      scenes: {}
    YAML
    with_spec(raw) do |slug|
      spec = described_class.load(slug)
      expect(spec.slug).to eq(slug)
      expect(spec.style_level[:mood]).to eq("calm_ordered")
      expect(spec.style_level[:content_type]).to eq("minimalist_modern")
      expect(spec.style_level[:frame_form]).to eq("angular")
    end
  end

  it "raises when no file exists" do
    expect { described_class.load("definitely-not-a-spec-#{SecureRandom.hex(4)}") }
      .to raise_error(KnowledgeBase::IncompleteSpecError)
  end

  it "rejects a blank style axis" do
    raw = <<~YAML
      slug: __SLUG__
      name: "Test"
      style_level:
        mood:
        content_type: minimalist_modern
        frame_form: angular
      scenes:
        s1:
          name: S1
          axes:
            wall_condition: neutral
            furniture_weight: light
            room_type: seated_room
            room_shape: none
            space_math: single
            color_role: line_only
    YAML
    with_spec(raw) do |slug|
      expect { described_class.load(slug).validate! }.to raise_error(KnowledgeBase::IncompleteSpecError)
    end
  end

  it "rejects an out-of-range axis value" do
    raw = <<~YAML
      slug: __SLUG__
      name: "Test"
      style_level:
        mood: nonsense
        content_type: minimalist_modern
        frame_form: angular
      scenes:
        s1:
          name: S1
          axes:
            wall_condition: neutral
            furniture_weight: light
            room_type: seated_room
            room_shape: none
            space_math: single
            color_role: line_only
    YAML
    with_spec(raw) do |slug|
      expect { described_class.load(slug).validate! }.to raise_error(KnowledgeBase::IncompleteSpecError)
    end
  end

  it "requires at least one scene template" do
    raw = <<~YAML
      slug: __SLUG__
      name: "Test"
      style_level:
        mood: calm_ordered
        content_type: minimalist_modern
        frame_form: angular
      scenes: {}
    YAML
    with_spec(raw) do |slug|
      expect { described_class.load(slug).validate! }.to raise_error(KnowledgeBase::IncompleteSpecError)
    end
  end

  it "returns a SceneSpec for a known scene id" do
    raw = <<~YAML
      slug: __SLUG__
      name: "Test"
      style_level:
        mood: calm_ordered
        content_type: minimalist_modern
        frame_form: angular
      scenes:
        s1:
          name: "Scene One"
          template_ref: scene_templates/s1.yml
          axes:
            wall_condition: neutral
            furniture_weight: light
            room_type: seated_room
            room_shape: none
            space_math: single
            color_role: line_only
    YAML
    with_spec(raw) do |slug|
      spec = described_class.load(slug)
      scene = spec.scene("s1")
      expect(scene.name).to eq("Scene One")
      expect(scene.wall_condition).to eq("neutral")
      expect(spec.scene_ids).to eq(["s1"])
    end
  end
end
