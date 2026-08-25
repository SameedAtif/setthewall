# Shared stubs for the image-generation and Etsy adapter factories. The pipeline
# picks adapters via ImageGeneration::Adapter.build / Etsy::Adapter.build, so specs
# stub the factory to return a deterministic fake rather than hitting the network.
module AdapterStubs
  class FakeImageAdapter
    attr_reader :name, :generated

    def initialize(urls: ["https://example.com/art.png"])
      @urls = urls
      @generated = []
    end

    def name = "fake"

    def generate(prompt:, n:, style_reference: [])
      @generated << { prompt: prompt, n: n }
      urls = Array.new(n) { |i| @urls[i % @urls.size] }
      ImageGeneration::Result.new(urls: urls, provider: name, model: "fake",
                                  estimated_cost_usd: 0.0, raw_response: nil)
    end

    def estimated_cost_usd(n:) = 0.0
  end

  class FakeEtsyAdapter
    attr_reader :name, :create_listing_payloads

    def initialize(listing_id: "12345")
      @listing_id = listing_id
      @create_listing_payloads = []
    end

    def name = "fake"

    def create_listing(payload:)
      @create_listing_payloads << payload
      Etsy::Result.new(listing_id: @listing_id, status: "published", raw_response: { "listing_id" => @listing_id })
    end

    def fetch_category_tree = [{ "id" => 1, "name" => "Art" }]

    def fetch_listing_stats(listing_id:, date:)
      { views: 10, favorites: 2, orders: 1, revenue: 25.0, search_terms: ["japandi"] }
    end
  end

  def stub_image_adapter(urls: ["https://example.com/art.png"])
    adapter = FakeImageAdapter.new(urls: urls)
    stub_singleton(ImageGeneration::Adapter, :build, -> { adapter }) { yield adapter }
  end

  def stub_etsy_adapter(listing_id: "12345")
    adapter = FakeEtsyAdapter.new(listing_id: listing_id)
    stub_singleton(Etsy::Adapter, :build, -> { adapter }) { yield adapter }
  end
end
