require "test_helper"

class WeeklyExportTest < ActiveSupport::TestCase
  test "excludes dirty runs from the export window" do
    dirty = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "dirty:abc",
                                status: "complete", published_at: Date.current)
    clean = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "abc123",
                                status: "complete", published_at: Date.current)

    result = Performance::WeeklyExport.call(week_ending: Date.current)
    assert_equal 1, result[:piece_count]

    File.delete(result[:json_path]) rescue nil
    File.delete(result[:markdown_path]) rescue nil
  end

  test "writes markdown and JSON exports" do
    PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s", kb_version: "abc123",
                        status: "complete", published_at: Date.current)

    result = Performance::WeeklyExport.call(week_ending: Date.current)
    assert File.exist?(result[:markdown_path])
    assert File.exist?(result[:json_path])

    data = JSON.parse(File.read(result[:json_path]))
    assert_equal 1, data["piece_count"]

    File.delete(result[:json_path]) rescue nil
    File.delete(result[:markdown_path]) rescue nil
  end
end
