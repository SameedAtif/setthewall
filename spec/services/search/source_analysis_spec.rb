require "rails_helper"

RSpec.describe Search::SourceAnalysis do
  it "returns distinct normalized hosts" do
    urls = %w[
      https://www.etsy.com/listing/1
      https://etsy.com/listing/2
      https://m.pinterest.com/pin/1
      https://pinterest.com/pin/2
      https://westelm.com/x
    ]
    expect(described_class.distinct_hosts(urls)).to match_array(%w[etsy.com pinterest.com westelm.com])
  end

  it "treats two URLs on one host as one source" do
    expect(described_class.distinct_hosts(%w[https://etsy.com/a https://www.etsy.com/b])).to eq(["etsy.com"])
  end

  it "ignores invalid URLs" do
    expect(described_class.distinct_hosts(["not a url", nil, ""])).to eq([])
  end
end
