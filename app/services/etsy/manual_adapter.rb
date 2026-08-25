module Etsy
  class ManualAdapter < Adapter
    def name = "manual"

    def create_listing(payload:)
      dir = Rails.root.join("tmp", "manual_etsy_payloads")
      dir.mkpath
      file = dir.join("listing_#{Time.current.to_i}.json")
      file.write(JSON.pretty_generate(payload))

      Result.new(
        listing_id: nil,
        status: "pending_manual",
        raw_response: { pending: true, payload_file: file.to_s }
      )
    end

    def fetch_category_tree = []   # returning [] triggers "no live taxonomy available" branch in P3_5
  end
end
