require "rails_helper"

RSpec.describe Performance::WeeklyExport do
  it "aggregates by axis and summarizes gate patterns" do
    spec, = build_test_spec
    piece = build_piece(slug: spec.slug)
    piece.kb_version = "abc123"
    piece.status = "complete"
    piece.published_at = Date.current
    piece.frame_material_category = "metal"
    piece.matting_technique = "standard_single_mat"
    piece.save!

    create(:performance_snapshot, piece_record: piece, captured_on: Date.current, views: 10, orders: 2)
    create(:human_gate, piece_record: piece, status: "approved", step_id: "P3_2", closed_at: Time.current)

    result = described_class.call(week_ending: Date.current)
    data = JSON.parse(File.read(result[:json_path]))

    expect(data["aggregates"]["mood"]).not_to be_empty
    expect(data["gate_patterns"]["P3_2"]["approved"]).to eq(1)
    expect(File.exist?(result[:markdown_path])).to be(true)
  ensure
    File.delete(result[:json_path]) rescue nil
    File.delete(result[:markdown_path]) rescue nil
  end
end

RSpec.describe Performance::EtsyStatsFetcher do
  it "fetches stats for every published piece" do
    piece = create(:piece_record, :complete, etsy_listing_id: "42", kb_version: "abc123")
    adapter = AdapterStubs::FakeEtsyAdapter.new
    stub_singleton(Etsy::Adapter, :build, -> { adapter }) do
      described_class.call(date: Date.current)
    end
    expect(piece.performance_snapshots.count).to eq(1)
  end
end
