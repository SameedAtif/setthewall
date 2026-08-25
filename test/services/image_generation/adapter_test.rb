require "test_helper"

class ImageGenerationAdapterTest < ActiveSupport::TestCase
  test "defaults to the manual adapter" do
    original = ENV["IMAGE_GEN_PROVIDER"]
    ENV["IMAGE_GEN_PROVIDER"] = "manual"
    assert_instance_of ImageGeneration::ManualAdapter, ImageGeneration::Adapter.build
  ensure
    ENV["IMAGE_GEN_PROVIDER"] = original
  end

  test "builds the replicate adapter when configured" do
    original = ENV["IMAGE_GEN_PROVIDER"]
    ENV["IMAGE_GEN_PROVIDER"] = "replicate"
    assert_instance_of ImageGeneration::ReplicateAdapter, ImageGeneration::Adapter.build
  ensure
    ENV["IMAGE_GEN_PROVIDER"] = original
  end

  test "raises on an unknown provider" do
    original = ENV["IMAGE_GEN_PROVIDER"]
    ENV["IMAGE_GEN_PROVIDER"] = "nonsense"
    assert_raises(ImageGeneration::GenerationError) { ImageGeneration::Adapter.build }
  ensure
    ENV["IMAGE_GEN_PROVIDER"] = original
  end

  test "manual adapter writes a prompt file and costs nothing" do
    result = ImageGeneration::ManualAdapter.new.generate(prompt: "test", n: 3)
    assert_equal 0.0, result.estimated_cost_usd
    assert result.raw_response[:pending]
    assert File.exist?(result.raw_response[:prompt_file])
  ensure
    File.delete(result.raw_response[:prompt_file]) rescue nil
  end
end
