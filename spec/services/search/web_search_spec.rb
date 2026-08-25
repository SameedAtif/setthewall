require "rails_helper"

RSpec.describe Tools::WebSearch do
  let(:tool) { described_class.new }

  around do |example|
    ENV["TAVILY_API_KEY"] = "test-key"
    example.run
  ensure
    ENV.delete("TAVILY_API_KEY")
  end

  def stub_post(response)
    tool.instance_variable_set(:@connection, double("connection", post: response))
  end

  it "returns results" do
    req = double("req")
    allow(req).to receive(:body=)
    conn = double("connection")
    allow(conn).to receive(:post).and_yield(req).and_return(
      double("response", success?: true,
                         body: JSON.generate("results" => [{ "title" => "t", "url" => "u", "content" => "c" }]))
    )
    tool.instance_variable_set(:@connection, conn)

    expect(tool.execute(query: "q")).to eq([{ title: "t", url: "u", snippet: "c" }])
  end

  it "returns an error on a failed request" do
    stub_post(double("response", success?: false, status: 500))
    expect(tool.execute(query: "q")).to eq({ error: "search request failed (HTTP 500)", query: "q" })
  end

  it "returns an error on empty results" do
    stub_post(double("response", success?: true, body: JSON.generate("results" => [])))
    expect(tool.execute(query: "q")).to eq({ error: "no results found", query: "q" })
  end

  it "returns an error when the connection raises" do
    conn = double("connection")
    allow(conn).to receive(:post).and_raise(Faraday::ConnectionFailed, "down")
    tool.instance_variable_set(:@connection, conn)
    expect(tool.execute(query: "q")).to match(hash_including(error: a_string_including("down")))
  end

  it "clamps max_results to 10" do
    stub_post(double("response", success?: true, body: JSON.generate("results" => [])))
    expect(tool.execute(query: "q", max_results: 99)).to eq({ error: "no results found", query: "q" })
  end
end
