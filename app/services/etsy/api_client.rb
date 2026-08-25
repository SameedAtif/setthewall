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

    # Added in module 07 — pulls per-listing metrics + shop search terms.
    # Verify exact endpoints against developers.etsy.com before running (same caveat as module 05).
    def fetch_listing_stats(listing_id:, date: Date.current)
      response = connection.get("application/shops/#{ENV.fetch('ETSY_SHOP_ID')}/listings/#{listing_id}/stats")
      raise ApiError, "Etsy stats fetch failed (HTTP #{response.status})" unless response.success?

      body = JSON.parse(response.body)
      {
        views: body.dig("views") || 0,
        favorites: body.dig("favorites") || 0,
        orders: body.dig("orders") || 0,
        revenue: body.dig("revenue") || 0,
        search_terms: Array(body.dig("search_terms"))
      }
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
