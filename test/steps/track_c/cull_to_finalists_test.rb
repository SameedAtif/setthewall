require "test_helper"

class CullToFinalistsTest < ActiveSupport::TestCase
  def build_piece(candidates)
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:test",
                        status: "pending", candidate_urls: candidates)
  end

  test "fails when there are no candidates" do
    result = Steps::TrackC::CullToFinalists.call(piece: build_piece([]), context: {})
    assert result.failed?
  end

  test "asks the human to cull when no finalists are proposed" do
    result = Steps::TrackC::CullToFinalists.call(piece: build_piece(%w[a b c]), context: {})
    assert result.awaiting_human?
    assert_includes result.message, "Cull the batch"
  end

  test "rejects finalists not present in the candidate set" do
    result = Steps::TrackC::CullToFinalists.call(piece: build_piece(%w[a b c]),
                                                 context: { finalist_urls: %w[a x] })
    assert result.failed?
  end

  test "rejects more finalists than the absolute max" do
    result = Steps::TrackC::CullToFinalists.call(piece: build_piece(%w[a b c d e]),
                                                 context: { finalist_urls: %w[a b c d e] })
    assert result.failed?
    assert_includes result.message, "absolute maximum"
  end

  test "persists finalists and asks for the chosen one" do
    piece = build_piece(%w[a b c d])
    result = Steps::TrackC::CullToFinalists.call(piece: piece, context: { finalist_urls: %w[a b c] })
    assert result.awaiting_human?
    assert_equal %w[a b c], piece.reload.finalist_urls
  end

  test "completes when a chosen url is provided" do
    piece = build_piece(%w[a b c])
    result = Steps::TrackC::CullToFinalists.call(piece: piece,
                                                 context: { finalist_urls: %w[a b], chosen_url: "a" })
    assert result.ok?
    assert_equal "a", piece.reload.chosen_url
  end

  test "rejects a chosen url not in finalists" do
    piece = build_piece(%w[a b c])
    result = Steps::TrackC::CullToFinalists.call(piece: piece,
                                                 context: { finalist_urls: %w[a b], chosen_url: "c" })
    assert result.failed?
  end
end
