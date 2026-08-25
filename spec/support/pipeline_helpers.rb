# Helpers to stand up on-disk pipeline fixtures (style specs, scene templates,
# art images) and track the files for cleanup after each example.
module PipelineHelpers
  def track_kb_file(path)
    (@tracked_kb_files ||= []) << path.to_s
  end

  def build_test_spec(slug: "test-#{SecureRandom.hex(6)}", scene_id: "s1", space_math: "single",
                      mood: "calm_ordered", content_type: "minimalist_modern")
    KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
      slug: slug, name: "Test", mood: mood,
      content_type: content_type, frame_form: "angular"
    )
    track_kb_file(Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml"))

    scene = KnowledgeBase::SceneSpecWriter.write_scene_axes(
      style_slug: slug, scene_id: scene_id, scene_name: "S1",
      template_ref: "scene_templates/#{scene_id}.yml",
      axes: { wall_condition: "neutral", furniture_weight: "light",
              room_type: "seated_room", room_shape: "none",
              space_math: space_math, color_role: "line_only" }
    )
    [KnowledgeBase::StyleSpec.load(slug), scene]
  end

  def build_piece(slug: nil, scene_id: "s1", mood: "calm_ordered",
                  content_type: "minimalist_modern", space_math: "single", **attrs)
    slug ||= "test-#{SecureRandom.hex(6)}"
    spec, scene = build_test_spec(slug: slug, scene_id: scene_id, mood: mood,
                                  content_type: content_type, space_math: space_math)
    PieceRecord.new(
      { style_spec_slug: spec.slug, scene_spec_id: scene_id,
        kb_version: "dirty:test", status: "pending" }.merge(attrs)
    ).tap { |p| p.apply_spec!(spec, scene) }
  end

  def build_scene_template(scene_id, room_type: "seated_room")
    assets = Pipeline::KB_ROOT.join("scene_templates/assets")
    FileUtils.mkdir_p(assets.to_s)

    scene_img = assets.join("#{scene_id}.png")
    Vips::Image.black(2400, 1600).write_to_file(scene_img.to_s)
    track_kb_file(scene_img)

    tpl = Pipeline::KB_ROOT.join("scene_templates", "#{scene_id}.yml")
    tpl.write(<<~YAML)
      id: #{scene_id}
      name: "Test scene"
      image_path: "scene_templates/assets/#{scene_id}.png"
      measurements:
        image_width_px: 2400
        image_height_px: 1600
        pixels_per_inch: 24
        furniture_top_edge_y_px: 900
        wall_zone: { x: 200, y: 100, width: 2000, height: 800 }
        seated_eye_level_y_px: 850
        standing_eye_level_y_px: 720
        furniture_width_px: 800
    YAML
    track_kb_file(tpl)
    tpl
  end

  def build_art_image
    path = Rails.root.join("tmp", "test_art", "#{SecureRandom.hex(8)}.png")
    FileUtils.mkdir_p(File.dirname(path))
    Vips::Image.black(100, 100).write_to_file(path.to_s)
    track_kb_file(path)
    path
  end

  # Drive one step through the dispatcher, returning the StepResult.
  def dispatch(step_id, piece, context = {})
    Workflow::StepDispatcher.call(step_id: step_id, piece: piece, context: context)
  end
end
