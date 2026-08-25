require "simplecov"
SimpleCov.start "rails" do
  skip "/test/"
  skip "/config/"
  skip "/db/"
  skip "/vendor/"
  skip "/tools/"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # --- knowledge-base file hygiene -------------------------------------
    # Writers in modules 01/02 write into knowledge_base/style_specs/*.yml. Track
    # every file a test creates so it's removed in teardown and never pollutes the
    # version-controlled knowledge base.
    teardown do
      (@tracked_kb_files || []).each { |f| File.delete(f) rescue nil }
    end

    def track_kb_file(path)
      (@tracked_kb_files ||= []) << path.to_s
    end

    def build_test_spec(slug: "test-#{SecureRandom.hex(6)}", scene_id: "s1")
      KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
        slug: slug, name: "Test", mood: "calm_ordered",
        content_type: "minimalist_modern", frame_form: "angular"
      )
      track_kb_file(Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml"))

      scene = KnowledgeBase::SceneSpecWriter.write_scene_axes(
        style_slug: slug, scene_id: scene_id, scene_name: "S1",
        template_ref: "scene_templates/#{scene_id}.yml",
        axes: { wall_condition: "neutral", furniture_weight: "light",
                room_type: "seated_room", room_shape: "none",
                space_math: "single", color_role: "line_only" }
      )
      [KnowledgeBase::StyleSpec.load(slug), scene]
    end

    def build_piece(slug: nil, scene_id: "s1", **attrs)
      spec, scene = build_test_spec(slug: slug, scene_id: scene_id)
      PieceRecord.new(
        { style_spec_slug: spec.slug, scene_spec_id: scene_id,
          kb_version: "dirty:test", status: "pending" }.merge(attrs)
      ).tap { |p| p.apply_spec!(spec, scene) }
    end
  end
end
