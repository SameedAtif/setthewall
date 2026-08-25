module Etsy
  class ApiClient < Adapter
    BASE_URL = "https://openapi.etsy.com/v3/"

    def name = "etsy_openapi_v3"

    def create_listing(payload:)
      response = connection.post("application/shops/#{ENV.fetch('ETSY_SHOP_ID')}/listings") do |req|
        req.body = payload
      end

      unless response.success?
        raise ApiError, "Etsy listing create failed (HTTP #{response.status}): #{response.body}"
      end

      body = JSON.parse(response.body)
      Result.new(listing_id: body["listing_id"].to_s, status: "published", raw_response: body)
    end

    def fetch_category_tree
      response = connection.get("application/seller-taxonomy/nodes")
      raise ApiError, "Etsy taxonomy fetch failed (HTTP #{response.status})" unless response.success?
      JSON.parse(response.body)["results"]
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.headers["x-api-key"] = ENV.fetch("ETSY_API_KEY")
        f.headers["Authorization"] = "Bearer #{ENV.fetch('ETSY_OAUTH_TOKEN')}"
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
