require "rails_helper"

RSpec.describe ImageGeneration::Adapter do
  around do |example|
    original = ENV["IMAGE_GEN_PROVIDER"]
    example.run
  ensure
    ENV["IMAGE_GEN_PROVIDER"] = original
  end

  it "defaults to the manual adapter" do
    ENV["IMAGE_GEN_PROVIDER"] = "manual"
    expect(described_class.build).to be_a(ImageGeneration::ManualAdapter)
  end

  it "builds the replicate adapter when configured" do
    ENV["IMAGE_GEN_PROVIDER"] = "replicate"
    expect(described_class.build).to be_a(ImageGeneration::ReplicateAdapter)
  end

  it "builds the gemini adapter when configured" do
    ENV["IMAGE_GEN_PROVIDER"] = "gemini"
    expect(described_class.build).to be_a(ImageGeneration::GeminiAdapter)
  end

  it "raises on an unknown provider" do
    ENV["IMAGE_GEN_PROVIDER"] = "nonsense"
    expect { described_class.build }.to raise_error(ImageGeneration::GenerationError)
  end

  it "manual adapter writes a prompt file and costs nothing" do
    result = ImageGeneration::ManualAdapter.new.generate(prompt: "test", n: 3)
    expect(result.estimated_cost_usd).to eq(0.0)
    expect(result.raw_response[:pending]).to be(true)
    expect(File.exist?(result.raw_response[:prompt_file])).to be(true)
  ensure
    File.delete(result.raw_response[:prompt_file]) rescue nil
  end

  it "manual adapter includes style references in the prompt file" do
    result = ImageGeneration::ManualAdapter.new.generate(prompt: "p", n: 1, style_reference: ["ref.png"])
    expect(File.read(result.raw_response[:prompt_file])).to include("ref.png")
  ensure
    File.delete(result.raw_response[:prompt_file]) rescue nil
  end
end
