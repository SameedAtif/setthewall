require "test_helper"

class PerformanceSnapshotTest < ActiveSupport::TestCase
  def build_piece
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test", status: "complete")
  end

  test "conversion_rate is zero when there are no views" do
    s = PerformanceSnapshot.new(views: 0, orders: 5)
    assert_equal 0.0, s.conversion_rate
  end

  test "conversion_rate divides orders by views" do
    s = PerformanceSnapshot.new(views: 100, orders: 2)
    assert_in_delta 0.02, s.conversion_rate
  end

  test "captured_on is unique per piece" do
    piece = build_piece
    PerformanceSnapshot.create!(piece_record: piece, captured_on: Date.current)
    dup = PerformanceSnapshot.new(piece_record: piece, captured_on: Date.current)
    assert_not dup.valid?
    assert_includes dup.errors[:captured_on], "has already been taken"
  end
end
