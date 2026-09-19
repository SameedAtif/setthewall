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
          desc: "Describe the thing you are looking for (e.g. \"whimsigoth wall art\", \"specimen " \
                "plate print\"), not your research task. Do NOT stack task or marketplace jargon " \
                "(\"Etsy listing\", \"bestseller\", \"analysis\") — those words retrieve SEO " \
                "roundups about selling, not the primary sources themselves."
    param :max_results, type: :integer, required: false,
          desc: "Number of results to return. Default 5, max 10."
    param :include_images, type: :boolean, required: false,
          desc: "Set true to also retrieve real image URLs found on the result pages. Default false (text only)."
    param :include_domains, type: :array, required: false,
          desc: "Only return results from these domains, e.g. [\"etsy.com\", \"pinterest.com\"]. " \
                "Use this to scope a query to a specific retailer, marketplace, or platform."
    param :exclude_domains, type: :array, required: false,
          desc: "Exclude results from these domains (e.g. known-promotional or aggregator domains)."

    def execute(query:, max_results: 5, include_images: false, include_domains: [], exclude_domains: [])
      max_results = max_results.to_i.clamp(1, 10)
      Rails.logger.info("WebSearch: #{query.inspect} (images=#{include_images}, " \
                        "domains=#{Array(include_domains).join(',')})")
      Workflow::StepLogging.log("Search: #{query}")

      response = connection.post("search") do |req|
        req.body = {
          api_key: ENV.fetch("TAVILY_API_KEY"),
          query: query,
          max_results: max_results,
          include_answer: false,
          search_depth: "basic",
          include_images: include_images,
          include_image_descriptions: include_images,
          include_domains: Array(include_domains).map(&:to_s).reject(&:blank?),
          exclude_domains: Array(exclude_domains).map(&:to_s).reject(&:blank?)
        }
      end

      unless response.success?
        trace(query, [], [], error: "search request failed (HTTP #{response.status})")
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

      normalized = results.map do |r|
        { title: r["title"], url: r["url"], snippet: r["content"].to_s.truncate(500) }
      end
      trace(query, normalized, images.map { |i| i[:url] })

      if results.empty? && images.empty?
        Rails.logger.info("WebSearch: #{query.inspect} -> 0 results")
        return { error: "no results found", query: query }
      end

      Rails.logger.info("WebSearch: #{query.inspect} -> #{results.size} results, #{images.size} images")
      Workflow::StepLogging.log("#{results.size} results, #{images.size} images")

      { results: normalized, images: images }
    rescue Faraday::Error, JSON::ParserError, Timeout::Error => e
      trace(query, [], [], error: e.message)
      { error: "search tool error: #{e.message}", query: query }
    end

    private

    # Records every search query and what it surfaced, so the dossier can show the exact queries
    # issued, the links (with titles) they returned, and how the query text was generated upstream.
    def trace(query, results, image_urls, error: nil)
      entry = {
        query: query,
        result_urls: results.map { |r| r[:url] },
        results: results,
        image_urls: image_urls
      }
      entry[:error] = error if error.present?
      (Thread.current[:web_search_trace] ||= []) << entry
    end

    def normalize_images(images)
      Array(images).filter_map do |img|
        next unless img

        img.is_a?(Hash) ? { url: img["url"], description: img["description"].to_s.truncate(120) } : { url: img, description: nil }
      end
    end

    def connection
      @connection ||= Faraday.new(url: "https://api.tavily.com/") do |f|
        f.request :json
        # Bound every call so a stuck connection can never hang the research step.
        f.options.open_timeout = ENV.fetch("SEARCH_OPEN_TIMEOUT_SECONDS", 8).to_i
        f.options.timeout      = ENV.fetch("SEARCH_READ_TIMEOUT_SECONDS", 15).to_i
        f.adapter Faraday.default_adapter
      end
    end
  end
end
