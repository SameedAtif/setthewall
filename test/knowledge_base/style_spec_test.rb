require "test_helper"

class StyleSpecTest < ActiveSupport::TestCase
  def with_spec(raw)
    slug = "test-spec-#{SecureRandom.hex(4)}"
    raw = raw.sub("__SLUG__", slug)
    path = Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml")
    path.write(raw)
    track_kb_file(path)
    yield slug
  end

  test "loads a valid style spec" do
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
      spec = KnowledgeBase::StyleSpec.load(slug)
      assert_equal slug, spec.slug
      assert_equal "calm_ordered", spec.style_level[:mood]
      assert_equal "minimalist_modern", spec.style_level[:content_type]
      assert_equal "angular", spec.style_level[:frame_form]
    end
  end

  test "load raises when no file exists" do
    assert_raises(KnowledgeBase::IncompleteSpecError) do
      KnowledgeBase::StyleSpec.load("definitely-not-a-spec-#{SecureRandom.hex(4)}")
    end
  end

  test "validate! rejects a blank style axis" do
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
      spec = KnowledgeBase::StyleSpec.load(slug)
      assert_raises(KnowledgeBase::IncompleteSpecError) { spec.validate! }
    end
  end

  test "validate! rejects an out-of-range axis value" do
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
      spec = KnowledgeBase::StyleSpec.load(slug)
      assert_raises(KnowledgeBase::IncompleteSpecError) { spec.validate! }
    end
  end

  test "validate! requires at least one scene template" do
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
      spec = KnowledgeBase::StyleSpec.load(slug)
      assert_raises(KnowledgeBase::IncompleteSpecError) { spec.validate! }
    end
  end

  test "scene returns a SceneSpec for a known scene id" do
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
      spec = KnowledgeBase::StyleSpec.load(slug)
      scene = spec.scene("s1")
      assert_equal "Scene One", scene.name
      assert_equal "neutral", scene.wall_condition
      assert_equal ["s1"], spec.scene_ids
    end
  end
end
