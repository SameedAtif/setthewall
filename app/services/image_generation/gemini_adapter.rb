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

      parts = [{ text: prompt }]
      Array(style_reference).each do |ref|
        part = inline_image_part(ref)
        parts << part if part
      end

      n.times do
        response = post_with_retry(parts)

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

    def post_with_retry(parts)
      response = nil
      3.times do |attempt|
        response = connection.post("models/#{MODEL}:generateContent") do |req|
          req.body = {
            contents: [{ parts: parts }],
            generationConfig: { responseModalities: ["IMAGE"] }
          }
        end
        break if response.success?
        sleep(2 * (attempt + 1))
      end
      response
    end

    def extract_image(data)
      parts = data.dig("candidates", 0, "content", "parts") || []
      parts.each do |part|
        inline = part["inlineData"]
        return [inline["data"], inline["mimeType"]] if inline && inline["data"]
      end
      [nil, nil]
    end

    def inline_image_part(path)
      return nil if path.blank?
      return nil unless File.exist?(path.to_s)

      mime = case File.extname(path.to_s).downcase
      when ".png" then "image/png"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".webp" then "image/webp"
      else "image/png"
      end

      { inlineData: { mimeType: mime, data: Base64.strict_encode64(File.binread(path.to_s)) } }
    rescue StandardError
      nil
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
