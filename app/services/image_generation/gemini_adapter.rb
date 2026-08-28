module ImageGeneration
  class GeminiAdapter < Adapter
    # Nano Banana image generation (gemini-2.5-flash-image) via the Gemini API.
    # Verify the current model id against Google's docs before running — image
    # model ids change without notice.
    MODEL = ENV.fetch("GEMINI_IMAGE_MODEL", "gemini-2.5-flash-image")
    BASE_URL = ENV.fetch("GEMINI_API_BASE", "https://generativelanguage.googleapis.com/v1beta")
    COST_PER_IMAGE_USD = ENV.fetch("GEMINI_COST_PER_IMAGE", "0.04").to_f

    def name = "gemini:#{MODEL}"

    def generate(prompt:, n:, style_reference: [])
      urls = []

      n.times do
        response = connection.post("models/#{MODEL}:generateContent") do |req|
          req.body = {
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { responseModalities: ["IMAGE"] }
          }
        end

        unless response.success?
          raise GenerationError, "Gemini error #{response.status}: #{response.body}"
        end

        base64, mime_type = extract_image(JSON.parse(response.body))
        raise GenerationError, "Gemini returned no image data" unless base64

        urls << save_image(base64, mime_type)
      end

      Result.new(urls: urls, provider: name, model: MODEL,
                 estimated_cost_usd: estimated_cost_usd(n: n),
                 raw_response: nil)
    end

    def estimated_cost_usd(n:) = (COST_PER_IMAGE_USD * n).round(4)

    private

    def extract_image(data)
      parts = data.dig("candidates", 0, "content", "parts") || []
      parts.each do |part|
        inline = part["inlineData"]
        return [inline["data"], inline["mimeType"]] if inline && inline["data"]
      end
      [nil, nil]
    end

    def save_image(base64, mime_type)
      ext = mime_type.to_s.split("/").last.to_s.sub("jpeg", "jpg").presence || "png"
      dir = Rails.root.join("tmp", "gemini_images")
      dir.mkpath
      file = dir.join("img_#{Time.current.to_i}_#{SecureRandom.hex(4)}.#{ext}")
      file.binwrite(Base64.decode64(base64))
      file.to_s
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.headers["x-goog-api-key"] = ENV.fetch("GEMINI_API_KEY")
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
