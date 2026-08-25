module ImageGeneration
  class ReplicateAdapter < Adapter
    # Verify the current Flux model slug against Replicate's docs before running in
    # production — Replicate model slugs and version hashes change without notice.
    # As of this plan's drafting date, the working slug is "black-forest-labs/flux-1.1-pro".
    # A build script should read this from ENV to avoid drift:
    MODEL = ENV.fetch("REPLICATE_MODEL_SLUG", "black-forest-labs/flux-1.1-pro")
    COST_PER_IMAGE_USD = ENV.fetch("REPLICATE_COST_PER_IMAGE", "0.04").to_f

    def name = "replicate:#{MODEL}"

    def generate(prompt:, n:, style_reference: [])
      urls = []

      n.times do
        response = connection.post("predictions") do |req|
          req.body = {
            model: MODEL,
            input: {
              prompt: prompt,
              aspect_ratio: "1:1",
              output_format: "png",
              output_quality: 95
            }.tap { |i| i[:image_prompt] = style_reference.first if style_reference.any? }
          }
        end

        raise GenerationError, "Replicate error #{response.status}: #{response.body}" unless response.success?

        prediction = JSON.parse(response.body)
        output = poll_until_complete(prediction["id"])
        urls.concat(Array(output).flatten)
      end

      Result.new(urls: urls, provider: name, model: MODEL,
                 estimated_cost_usd: estimated_cost_usd(n: n),
                 raw_response: nil)
    end

    def estimated_cost_usd(n:) = (COST_PER_IMAGE_USD * n).round(4)

    private

    def poll_until_complete(id, max_seconds: 180)
      deadline = Time.current + max_seconds
      loop do
        raise GenerationError, "Replicate prediction #{id} timed out" if Time.current > deadline

        resp = connection.get("predictions/#{id}")
        data = JSON.parse(resp.body)
        case data["status"]
        when "succeeded" then return data["output"]
        when "failed", "canceled" then raise GenerationError, "Replicate failed: #{data['error']}"
        end
        sleep 2
      end
    end

    def connection
      @connection ||= Faraday.new(url: "https://api.replicate.com/v1/") do |f|
        f.headers["Authorization"] = "Bearer #{ENV.fetch('REPLICATE_API_KEY')}"
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
