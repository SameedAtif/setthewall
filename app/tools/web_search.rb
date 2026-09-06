module Tools
  class WebSearch < RubyLLM::Tool
    MAX_IMAGES = 5   # include_images can return hundreds per query; cap to keep the LLM context lean

    description <<~DESC
      Search the live web. Returns titles, URLs, and content snippets from real,
      independently-sourced pages. Use this whenever you need current information, cannot
      answer reliably from training data, or need to attribute a claim to a real, checkable
      source. Issue multiple distinct, focused queries rather than one broad query when you
      need to cross-check a finding across independent sources.

      Set include_images: true when you need actual photo URLs — e.g. building a visual
      reference set — not just page links. Without it, results are text-only and contain no
      usable image URLs; do not report or invent an image URL you did not actually receive
      from a call with include_images: true.
    DESC

    param :query, type: :string,
          desc: "A focused search query, 2-6 words works best."
    param :max_results, type: :integer, required: false,
          desc: "Number of results to return. Default 5, max 10."
    param :include_images, type: :boolean, required: false,
          desc: "Set true to also retrieve real image URLs found on the result pages. Default false (text only)."

    def execute(query:, max_results: 5, include_images: false)
      max_results = max_results.to_i.clamp(1, 10)
      Rails.logger.info("WebSearch: #{query.inspect} (images=#{include_images})")

      response = connection.post("search") do |req|
        req.body = {
          api_key: ENV.fetch("TAVILY_API_KEY"),
          query: query,
          max_results: max_results,
          include_answer: false,
          search_depth: "basic",
          include_images: include_images,
          include_image_descriptions: include_images
        }
      end

      unless response.success?
        return { error: "search request failed (HTTP #{response.status})", query: query }
      end

      body = JSON.parse(response.body)
      results = body["results"] || []

      # Tavily returns image URLs either top-level (with include_image_descriptions) or inside
      # each result (bare URL strings) depending on the request — collect both and normalize to
      # one {url:, description:} shape so the caller/model doesn't depend on the variant.
      images = normalize_images(body["images"]) +
               results.flat_map { |r| normalize_images(r["images"]) }
      images = images.uniq { |img| img[:url] }.first(MAX_IMAGES)

      if results.empty? && images.empty?
        Rails.logger.info("WebSearch: #{query.inspect} -> 0 results")
        return { error: "no results found", query: query }
      end

      Rails.logger.info("WebSearch: #{query.inspect} -> #{results.size} results, #{images.size} images")

      {
        results: results.map { |r|
          { title: r["title"], url: r["url"], snippet: r["content"].to_s.truncate(500) }
        },
        images: images
      }
    rescue Faraday::Error, JSON::ParserError => e
      { error: "search tool error: #{e.message}", query: query }
    end

    private

    def normalize_images(images)
      Array(images).filter_map do |img|
        next unless img

        img.is_a?(Hash) ? { url: img["url"], description: img["description"].to_s.truncate(120) } : { url: img, description: nil }
      end
    end

    def connection
      @connection ||= Faraday.new(url: "https://api.tavily.com/") do |f|
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
