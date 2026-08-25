require "rails_helper"

RSpec.describe ImageGeneration::ReplicateAdapter do
  let(:adapter) { described_class.new }

  def stub_connection(conn)
    adapter.instance_variable_set(:@connection, conn)
  end

  it "names itself with the model slug" do
    expect(adapter.name).to include("replicate:")
  end

  it "estimates cost per image" do
    expect(adapter.estimated_cost_usd(n: 3)).to be_within(0.001).of(0.12)
  end

  it "generates N images" do
    req = double("req")
    allow(req).to receive(:body=)
    conn = double("connection")
    allow(conn).to receive(:post).and_yield(req).and_return(double("resp", success?: true, body: JSON.generate("id" => "p1")))
    stub_connection(conn)
    allow(adapter).to receive(:poll_until_complete).and_return(["url1"])

    result = adapter.generate(prompt: "p", n: 2)
    expect(result.urls).to eq(%w[url1 url1])
    expect(result.estimated_cost_usd).to be_within(0.001).of(0.08)
  end

  it "passes a style reference to the provider" do
    req = double("req")
    allow(req).to receive(:body=)
    conn = double("connection")
    allow(conn).to receive(:post).and_yield(req).and_return(double("resp", success?: true, body: JSON.generate("id" => "p1")))
    stub_connection(conn)
    allow(adapter).to receive(:poll_until_complete).and_return(["url1"])

    adapter.generate(prompt: "p", n: 1, style_reference: ["ref.png"])
  end

  it "raises when the create call fails" do
    conn = double("connection", post: double("resp", success?: false, status: 500, body: "err"))
    stub_connection(conn)
    expect { adapter.generate(prompt: "p", n: 1) }.to raise_error(ImageGeneration::GenerationError)
  end

  it "polls until succeeded (with a processing round)" do
    conn = double("connection")
    allow(conn).to receive(:get).and_return(
      double("resp", body: JSON.generate("status" => "processing")),
      double("resp", body: JSON.generate("status" => "succeeded", "output" => ["url"]))
    )
    stub_connection(conn)
    expect(adapter.send(:poll_until_complete, "id")).to eq(["url"])
  end

  it "raises when the prediction fails" do
    conn = double("connection", get: double("resp", body: JSON.generate("status" => "failed", "error" => "boom")))
    stub_connection(conn)
    expect { adapter.send(:poll_until_complete, "id") }.to raise_error(ImageGeneration::GenerationError, /boom/)
  end

  it "raises on timeout" do
    conn = double("connection")
    stub_connection(conn)
    now = Time.current
    allow(Time).to receive(:current).and_return(now, now + 200)
    expect { adapter.send(:poll_until_complete, "id", max_seconds: 180) }.to raise_error(ImageGeneration::GenerationError, /timed out/)
  end
end
