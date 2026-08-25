require "rails_helper"

RSpec.describe Performance::WeeklyExport do
  it "excludes dirty runs from the export window" do
    create(:piece_record, :complete, kb_version: "dirty:abc")
    create(:piece_record, :complete, kb_version: "abc123")

    result = described_class.call(week_ending: Date.current)
    expect(result[:piece_count]).to eq(1)
  ensure
    File.delete(result[:json_path]) rescue nil
    File.delete(result[:markdown_path]) rescue nil
  end

  it "writes markdown and JSON exports" do
    create(:piece_record, :complete, kb_version: "abc123")

    result = described_class.call(week_ending: Date.current)
    expect(File.exist?(result[:markdown_path])).to be(true)
    expect(File.exist?(result[:json_path])).to be(true)

    data = JSON.parse(File.read(result[:json_path]))
    expect(data["piece_count"]).to eq(1)
  ensure
    File.delete(result[:json_path]) rescue nil
    File.delete(result[:markdown_path]) rescue nil
  end
end
