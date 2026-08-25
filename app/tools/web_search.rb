module Tools
  class WebSearch < RubyLLM::Tool
    description <<~DESC
      Search the live web. Returns titles, URLs, and content snippets from real,
      independently-sourced pages. Use this whenever you need current information, cannot
      answer reliably from training data, or need to attribute a claim to a real, checkable
      source. Issue multiple distinct, focused queries rather than one broad query when you
      need to cross-check a finding across independent sources.
    DESC

    param :query, type: :string,
          desc: "A focused search query, 2-6 words works best."
    param :max_results, type: :integer, required: false,
          desc: "Number of results to return. Default 5, max 10."

    def execute(query:, max_results: 5)
      max_results = max_results.to_i.clamp(1, 10)

      response = connection.post("search") do |req|
        req.body = {
          api_key: ENV.fetch("TAVILY_API_KEY"),
          query: query,
          max_results: max_results,
          include_answer: false,
          search_depth: "basic"
        }
      end

      unless response.success?
        return { error: "search request failed (HTTP #{response.status})", query: query }
      end

      results = JSON.parse(response.body)["results"] || []
      if results.empty?
        return { error: "no results found", query: query }
      end

      results.map do |r|
        {
          title: r["title"],
          url: r["url"],
          snippet: r["content"].to_s.truncate(500)
        }
      end
    rescue Faraday::Error, JSON::ParserError => e
      { error: "search tool error: #{e.message}", query: query }
    end

    private

    def connection
      @connection ||= Faraday.new(url: "https://api.tavily.com/") do |f|
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
