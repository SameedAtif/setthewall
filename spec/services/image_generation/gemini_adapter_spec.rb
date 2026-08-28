require "rails_helper"

RSpec.describe ImageGeneration::GeminiAdapter do
  let(:adapter) { described_class.new }

  def stub_connection(response_or_block)
    adapter.instance_variable_set(:@connection, response_or_block)
  end

  around do |example|
    ENV["GEMINI_API_KEY"] = "test-key"
    example.run
  ensure
    ENV.delete("GEMINI_API_KEY")
  end

  it "names itself with the model" do
    expect(adapter.name).to eq("gemini:gemini-3.1-flash-image")
  end

  it "estimates cost per image" do
    expect(adapter.estimated_cost_usd(n: 3)).to be_within(0.001).of(0.12)
  end

  it "generates an image and writes it to disk" do
    req = double("req")
    allow(req).to receive(:body=)
    conn = double("connection")
    body = {
      "candidates" => [{ "content" => { "parts" => [
        { "inlineData" => { "mimeType" => "image/png", "data" => Base64.strict_encode64("pngdata") } }
      ] } }]
    }
    allow(conn).to receive(:post).and_yield(req).and_return(double("resp", success?: true, body: JSON.generate(body)))
    stub_connection(conn)

    result = adapter.generate(prompt: "p", n: 1)
    expect(result.urls.size).to eq(1)
    expect(File.read(result.urls.first)).to eq("pngdata")
  ensure
    File.delete(result&.urls&.first) rescue nil
  end

  it "raises on a failed request" do
    conn = double("connection", post: double("resp", success?: false, status: 429, body: "quota"))
    stub_connection(conn)
    expect { adapter.generate(prompt: "p", n: 1) }.to raise_error(ImageGeneration::GenerationError, /429/)
  end

  it "raises when no image is returned" do
    conn = double("connection", post: double("resp", success?: true, body: JSON.generate("candidates" => [])))
    stub_connection(conn)
    expect { adapter.generate(prompt: "p", n: 1) }.to raise_error(ImageGeneration::GenerationError, /no image/)
  end

  it "builds a Faraday connection" do
    expect(described_class.new.send(:connection)).to be_a(Faraday::Connection)
  end
end
