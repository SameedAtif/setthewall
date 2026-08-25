require "test_helper"

class StyleSpecWriterTest < ActiveSupport::TestCase
  test "creates and round-trips a style spec" do
    slug = "test-writer-#{SecureRandom.hex(4)}"
    spec = KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
      slug: slug, name: "T", mood: "calm_ordered",
      content_type: "minimalist_modern", frame_form: "angular"
    )
    track_kb_file(spec.path)

    assert_equal slug, spec.slug
    reloaded = KnowledgeBase::StyleSpec.load(slug)
    assert_equal "calm_ordered", reloaded.style_level[:mood]
    assert_equal "minimalist_modern", reloaded.style_level[:content_type]
    assert_equal "angular", reloaded.style_level[:frame_form]
  end

  test "rejects an out-of-range style axis" do
    slug = "test-writer-bad-#{SecureRandom.hex(4)}"
    assert_raises(KnowledgeBase::IncompleteSpecError) do
      KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
        slug: slug, name: "T", mood: "nonsense",
        content_type: "minimalist_modern", frame_form: "angular"
      )
    end
    refute File.exist?(Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml"))
  end

  test "updating style level preserves existing scenes" do
    slug = "test-writer-#{SecureRandom.hex(4)}"
    build_test_spec(slug: slug)

    KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
      slug: slug, name: "T2", mood: "bold_active",
      content_type: "portrait_still_life", frame_form: "rounded"
    )

    reloaded = KnowledgeBase::StyleSpec.load(slug)
    assert_equal "bold_active", reloaded.style_level[:mood]
    assert_includes reloaded.scene_ids, "s1"
  end
end
