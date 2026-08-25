require "test_helper"

class SceneSpecWriterTest < ActiveSupport::TestCase
  def valid_axes
    { wall_condition: "neutral", furniture_weight: "light", room_type: "seated_room",
      room_shape: "none", space_math: "single", color_role: "line_only" }
  end

  def locked_spec(slug: "test-scene-writer-#{SecureRandom.hex(4)}")
    KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
      slug: slug, name: "T", mood: "calm_ordered",
      content_type: "minimalist_modern", frame_form: "angular"
    )
    track_kb_file(Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml"))
    slug
  end

  test "refuses to write scene axes before the style level is locked" do
    assert_raises(KnowledgeBase::IncompleteSpecError) do
      KnowledgeBase::SceneSpecWriter.write_scene_axes(
        style_slug: "nonexistent-#{SecureRandom.hex(4)}", scene_id: "s1", scene_name: "S1",
        template_ref: "x.yml", axes: valid_axes
      )
    end
  end

  test "writes scene axes and produces a valid spec" do
    slug = locked_spec

    scene = KnowledgeBase::SceneSpecWriter.write_scene_axes(
      style_slug: slug, scene_id: "s1", scene_name: "S1",
      template_ref: "scene_templates/s1.yml", axes: valid_axes
    )

    assert_equal "s1", scene.id
    assert_equal "neutral", scene.wall_condition
    assert_equal "line_only", scene.color_role
    KnowledgeBase::StyleSpec.load(slug).validate!
  end

  test "rejects an invalid axis value" do
    slug = locked_spec

    assert_raises(KnowledgeBase::IncompleteSpecError) do
      KnowledgeBase::SceneSpecWriter.write_scene_axes(
        style_slug: slug, scene_id: "s2", scene_name: "S2",
        template_ref: "x.yml", axes: valid_axes.merge(wall_condition: "invalid")
      )
    end
  end

  test "rejects blank axes" do
    slug = locked_spec

    assert_raises(KnowledgeBase::IncompleteSpecError) do
      KnowledgeBase::SceneSpecWriter.write_scene_axes(
        style_slug: slug, scene_id: "s3", scene_name: "S3",
        template_ref: "x.yml", axes: valid_axes.merge(color_role: nil)
      )
    end
  end
end
