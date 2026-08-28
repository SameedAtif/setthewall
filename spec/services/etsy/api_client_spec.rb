require "rails_helper"

RSpec.describe Etsy::ApiClient do
  let(:client) { described_class.new }

  def stub_connection(conn)
    client.instance_variable_set(:@connection, conn)
  end

  around do |example|
    original = ENV.to_h.slice("ETSY_SHOP_ID", "ETSY_API_KEY", "ETSY_OAUTH_TOKEN")
    ENV["ETSY_SHOP_ID"] = "99"
    ENV["ETSY_API_KEY"] = "key"
    ENV["ETSY_OAUTH_TOKEN"] = "tok"
    example.run
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  it "names itself" do
    expect(client.name).to eq("etsy_openapi_v3")
  end

  it "creates a listing" do
    req = double("req")
    allow(req).to receive(:body=)
    conn = double("connection")
    allow(conn).to receive(:post).and_yield(req).and_return(double("resp", success?: true, body: JSON.generate("listing_id" => 42)))
    stub_connection(conn)

    result = client.create_listing(payload: { title: "t" })
    expect(result.listing_id).to eq("42")
    expect(result.status).to eq("published")
  end

  it "raises on a failed create" do
    conn = double("connection", post: double("resp", success?: false, status: 400, body: "bad"))
    stub_connection(conn)
    expect { client.create_listing(payload: {}) }.to raise_error(Etsy::ApiError)
  end

  it "fetches the category tree" do
    conn = double("connection", get: double("resp", success?: true, body: JSON.generate("results" => [{ "id" => 1 }])))
    stub_connection(conn)
    expect(client.fetch_category_tree).to eq([{ "id" => 1 }])
  end

  it "raises on a failed taxonomy fetch" do
    conn = double("connection", get: double("resp", success?: false, status: 500))
    stub_connection(conn)
    expect { client.fetch_category_tree }.to raise_error(Etsy::ApiError)
  end

  it "fetches listing stats" do
    body = { "views" => 5, "favorites" => 1, "orders" => 2, "revenue" => 30.0, "search_terms" => ["x"] }
    conn = double("connection", get: double("resp", success?: true, body: JSON.generate(body)))
    stub_connection(conn)

    stats = client.fetch_listing_stats(listing_id: "42")
    expect(stats[:views]).to eq(5)
    expect(stats[:search_terms]).to eq(["x"])
  end
end
