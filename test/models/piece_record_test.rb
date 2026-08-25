require "test_helper"

class PieceRecordTest < ActiveSupport::TestCase
  test "is invalid without the KB linkage fields" do
    piece = PieceRecord.new
    assert_not piece.valid?
    assert_includes piece.errors[:style_spec_slug], "can't be blank"
    assert_includes piece.errors[:kb_version], "can't be blank"
  end

  test "validates status inclusion" do
    piece = PieceRecord.new(style_spec_slug: "x", scene_spec_id: "s",
                            kb_version: "abc", status: "bogus")
    assert_not piece.valid?
    assert_includes piece.errors[:status], "is not included in the list"
  end

  test "dirty_run? is true only for dirty-prefixed KB versions" do
    piece = PieceRecord.new(kb_version: "dirty:abc")
    assert piece.dirty_run?
    piece.kb_version = "abc123"
    assert_not piece.dirty_run?
  end

  test "trustworthy scope excludes dirty runs" do
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:abc", status: "complete", published_at: Time.current)
    clean = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "abc123", status: "complete", published_at: Time.current)

    assert_includes PieceRecord.trustworthy, clean
    assert_equal 1, PieceRecord.published.trustworthy.count
  end

  test "apply_spec! denormalizes the nine axes" do
    spec, scene = build_test_spec
    piece = PieceRecord.new(style_spec_slug: spec.slug, scene_spec_id: "s1", kb_version: "dirty:test", status: "pending")
    piece.apply_spec!(spec, scene)

    assert_equal "calm_ordered", piece.mood
    assert_equal "minimalist_modern", piece.content_type
    assert_equal "angular", piece.frame_form
    assert_equal "neutral", piece.wall_condition
    assert_equal "line_only", piece.color_role
  end

  test "log_step! appends an audit entry" do
    piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test", status: "pending")
    piece.log_step!(step_id: "C1", mechanism: :image_gen, outcome: :ok, detail: { n: 3 })

    assert_equal 1, piece.reload.step_log.size
    assert_equal "C1", piece.step_log.first["step_id"]
    assert_equal "ok", piece.step_log.first["outcome"]
  end
end
