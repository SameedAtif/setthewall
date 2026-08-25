require "rails_helper"

RSpec.describe Etsy::Adapter do
  around do |example|
    original = ENV["ETSY_ADAPTER"]
    example.run
  ensure
    ENV["ETSY_ADAPTER"] = original
  end

  it "defaults to the manual adapter" do
    ENV["ETSY_ADAPTER"] = "manual"
    expect(described_class.build).to be_a(Etsy::ManualAdapter)
  end

  it "builds the api adapter when configured" do
    ENV["ETSY_ADAPTER"] = "api"
    expect(described_class.build).to be_a(Etsy::ApiClient)
  end

  it "raises on an unknown adapter" do
    ENV["ETSY_ADAPTER"] = "nonsense"
    expect { described_class.build }.to raise_error(Etsy::ApiError)
  end

  it "manual adapter writes a payload file and returns pending_manual" do
    result = Etsy::ManualAdapter.new.create_listing(payload: { title: "t" })
    expect(result.status).to eq("pending_manual")
    expect(File.exist?(result.raw_response[:payload_file])).to be(true)
  ensure
    File.delete(result.raw_response[:payload_file]) rescue nil
  end

  it "manual adapter returns an empty category tree" do
    expect(Etsy::ManualAdapter.new.fetch_category_tree).to eq([])
  end
end
