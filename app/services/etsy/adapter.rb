module Etsy
  class ApiError < StandardError; end

  Result = Struct.new(:listing_id, :status, :raw_response, keyword_init: true)

  class Adapter
    def self.build
      case ENV.fetch("ETSY_ADAPTER", "manual")
      when "manual" then ManualAdapter.new
      when "api"    then ApiClient.new
      else raise ApiError, "Unknown ETSY_ADAPTER=#{ENV['ETSY_ADAPTER']}"
      end
    end

    def name = raise(NotImplementedError)

    # payload: full listing hash (title, description, tags, price, quantity, photos, policy...)
    # Returns Result with listing_id set if published.
    def create_listing(payload:) = raise(NotImplementedError)

    # Fetches the live category tree for filling attributes properly.
    def fetch_category_tree = raise(NotImplementedError)
  end
end
