require "rails_helper"

RSpec.describe Performance::EtsyStatsFetcher do
  it "skips the manual adapter" do
    stub_singleton(Etsy::Adapter, :build, -> { Etsy::ManualAdapter.new }) do
      piece = create(:piece_record, :complete, etsy_listing_id: "42")
      described_class.fetch_and_upsert(piece, Date.current)
      expect(piece.performance_snapshots.count).to eq(0)
    end
  end

  it "fetches and upserts stats" do
    adapter = AdapterStubs::FakeEtsyAdapter.new
    stub_singleton(Etsy::Adapter, :build, -> { adapter }) do
      piece = create(:piece_record, :complete, etsy_listing_id: "42")
      described_class.fetch_and_upsert(piece, Date.current)
      snap = piece.performance_snapshots.first
      expect(snap.views).to eq(10)
      expect(snap.search_terms).to eq(["japandi"])
    end
  end

  it "logs a warning when the fetch fails" do
    adapter = double("adapter", name: "api")
    allow(adapter).to receive(:fetch_listing_stats).and_raise(Etsy::ApiError, "boom")
    stub_singleton(Etsy::Adapter, :build, -> { adapter }) do
      piece = create(:piece_record, :complete, etsy_listing_id: "42")
      expect(Rails.logger).to receive(:warn).with(a_string_including("boom"))
      described_class.fetch_and_upsert(piece, Date.current)
    end
  end
end
