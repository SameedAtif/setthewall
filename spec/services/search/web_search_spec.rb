require "rails_helper"

RSpec.describe Tools::WebSearch do
  let(:tool) { described_class.new }

  around do |example|
    ENV["TAVILY_API_KEY"] = "test-key"
    example.run
  ensure
    ENV.delete("TAVILY_API_KEY")
  end

  def stub_search(body:, &assert_body)
    req = double("req")
    if assert_body
      allow(req).to receive(:body=) { |b| assert_body.call(b) }
    else
      allow(req).to receive(:body=)
    end
    conn = double("connection")
    allow(conn).to receive(:post).and_yield(req).and_return(
      double("response", success?: true, body: JSON.generate(body))
    )
    tool.instance_variable_set(:@connection, conn)
  end

  it "returns results and no images by default (include_images false)" do
    stub_search(body: { "results" => [{ "title" => "t", "url" => "u", "content" => "c" }] }) do |b|
      expect(b[:include_images]).to be(false)
      expect(b[:include_image_descriptions]).to be(false)
    end

    expect(tool.execute(query: "q")).to eq(
      results: [{ title: "t", url: "u", snippet: "c" }],
      images: []
    )
  end

  it "requests images and returns top-level image objects when include_images is true" do
    stub_search(body: {
      "results" => [{ "title" => "t", "url" => "u", "content" => "c" }],
      "images" => [{ "url" => "https://img1", "description" => "a framed print" }]
    }) do |b|
      expect(b[:include_images]).to be(true)
      expect(b[:include_image_descriptions]).to be(true)
    end

    expect(tool.execute(query: "q", include_images: true)).to eq(
      results: [{ title: "t", url: "u", snippet: "c" }],
      images: [{ url: "https://img1", description: "a framed print" }]
    )
  end

  it "normalizes per-result image URL strings" do
    stub_search(body: {
      "results" => [{ "title" => "t", "url" => "u", "content" => "c",
                      "images" => %w[https://img1 https://img2] }]
    })

    result = tool.execute(query: "q", include_images: true)
    expect(result[:images]).to eq([{ url: "https://img1", description: nil },
                                   { url: "https://img2", description: nil }])
  end

  it "deduplicates images across top-level and per-result sources" do
    stub_search(body: {
      "results" => [{ "title" => "t", "url" => "u", "content" => "c", "images" => ["https://img1"] }],
      "images" => ["https://img1", "https://img2"]
    })

    result = tool.execute(query: "q", include_images: true)
    expect(result[:images].map { |i| i[:url] }).to eq(%w[https://img1 https://img2])
  end

  it "caps images to prevent context overflow" do
    many = (1..20).map { |n| "https://img#{n}" }
    stub_search(body: { "results" => [{ "title" => "t", "url" => "u", "content" => "c" }], "images" => many })

    result = tool.execute(query: "q", include_images: true)
    expect(result[:images].size).to eq(described_class::MAX_IMAGES)
  end

  it "returns an error on a failed request" do
    tool.instance_variable_set(:@connection,
                               double("connection", post: double("response", success?: false, status: 500)))
    expect(tool.execute(query: "q")).to eq({ error: "search request failed (HTTP 500)", query: "q" })
  end

  it "returns an error on empty results and images" do
    tool.instance_variable_set(:@connection,
                               double("connection", post: double("response", success?: true, body: JSON.generate("results" => []))))
    expect(tool.execute(query: "q")).to eq({ error: "no results found", query: "q" })
  end

  it "returns an error when the connection raises" do
    conn = double("connection")
    allow(conn).to receive(:post).and_raise(Faraday::ConnectionFailed, "down")
    tool.instance_variable_set(:@connection, conn)
    expect(tool.execute(query: "q")).to match(hash_including(error: a_string_including("down")))
  end

  it "clamps max_results to 10" do
    tool.instance_variable_set(:@connection,
                               double("connection", post: double("response", success?: true, body: JSON.generate("results" => []))))
    expect(tool.execute(query: "q", max_results: 99)).to eq({ error: "no results found", query: "q" })
  end

  it "passes include_domains and exclude_domains to the API" do
    stub_search(body: { "results" => [{ "title" => "t", "url" => "u", "content" => "c" }] }) do |b|
      expect(b[:include_domains]).to eq(%w[etsy.com pinterest.com])
      expect(b[:exclude_domains]).to eq(["spam.com"])
    end

    tool.execute(query: "q", include_domains: %w[etsy.com pinterest.com], exclude_domains: ["spam.com"])
  end

  it "records the query and URLs into the thread-local search trace" do
    Thread.current[:web_search_trace] = []
    stub_search(body: {
      "results" => [{ "title" => "t", "url" => "u", "content" => "c" }],
      "images" => [{ "url" => "https://img1", "description" => "x" }]
    })

    tool.execute(query: "q", include_images: true)

    trace = Thread.current[:web_search_trace]
    expect(trace.size).to eq(1)
    expect(trace.first[:query]).to eq("q")
    expect(trace.first[:result_urls]).to eq(["u"])
    expect(trace.first[:image_urls]).to eq(["https://img1"])
  ensure
    Thread.current[:web_search_trace] = nil
  end
end
