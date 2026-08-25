require "rails_helper"

RSpec.describe Etsy::ApiClient do
  it "builds a Faraday connection" do
    client = described_class.new
    conn = client.send(:connection)
    expect(conn).to be_a(Faraday::Connection)
  end
end

RSpec.describe ImageGeneration::ReplicateAdapter do
  it "builds a Faraday connection" do
    adapter = described_class.new
    expect(adapter.send(:connection)).to be_a(Faraday::Connection)
  end

  it "estimates cost for zero images" do
    expect(described_class.new.estimated_cost_usd(n: 0)).to eq(0.0)
  end
end

RSpec.describe Tools::WebSearch do
  it "builds a Faraday connection" do
    tool = described_class.new
    expect(tool.send(:connection)).to be_a(Faraday::Connection)
  end
end

RSpec.describe ImageGeneration::ManualAdapter do
  it "estimates zero cost" do
    expect(described_class.new.estimated_cost_usd(n: 5)).to eq(0.0)
  end

  it "names itself manual" do
    expect(described_class.new.name).to eq("manual")
  end
end
