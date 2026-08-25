require "test_helper"

class EtsyAdapterTest < ActiveSupport::TestCase
  test "defaults to the manual adapter" do
    original = ENV["ETSY_ADAPTER"]
    ENV["ETSY_ADAPTER"] = "manual"
    assert_instance_of Etsy::ManualAdapter, Etsy::Adapter.build
  ensure
    ENV["ETSY_ADAPTER"] = original
  end

  test "builds the api adapter when configured" do
    original = ENV["ETSY_ADAPTER"]
    ENV["ETSY_ADAPTER"] = "api"
    assert_instance_of Etsy::ApiClient, Etsy::Adapter.build
  ensure
    ENV["ETSY_ADAPTER"] = original
  end

  test "raises on an unknown adapter" do
    original = ENV["ETSY_ADAPTER"]
    ENV["ETSY_ADAPTER"] = "nonsense"
    assert_raises(Etsy::ApiError) { Etsy::Adapter.build }
  ensure
    ENV["ETSY_ADAPTER"] = original
  end

  test "manual adapter writes a payload file and returns pending_manual" do
    result = Etsy::ManualAdapter.new.create_listing(payload: { title: "t" })
    assert_equal "pending_manual", result.status
    assert File.exist?(result.raw_response[:payload_file])
  ensure
    File.delete(result.raw_response[:payload_file]) rescue nil
  end

  test "manual adapter returns an empty category tree" do
    assert_equal [], Etsy::ManualAdapter.new.fetch_category_tree
  end
end
