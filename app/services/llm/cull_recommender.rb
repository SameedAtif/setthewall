module Llm
  # A vision pass that ranks a cull batch and proposes finalists + a chosen, with per-candidate
  # reasoning, for the human to review at C2. Never raises: on any failure it returns an empty
  # recommendation so the gate still shows the candidates.
  class CullRecommender
    MAX_FINALISTS = 3

    def self.call(piece:, urls: nil) = new(piece: piece, urls: urls).call

    def initialize(piece:, urls: nil)
      @piece = piece
      @urls = Array(urls).presence || Array(piece&.candidate_urls)
    end

    def call
      return {} if @urls.empty?

      content = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                      .with_schema(Schemas::TrackC::CullRecommendationSchema)
                      .ask(prompt, with: @urls).content
      normalize(Pipeline::Json.normalize(content))
    rescue StandardError => e
      Rails.logger.warn("[Llm::CullRecommender] #{e.class}: #{e.message}")
      {}
    end

    private

    def normalize(data)
      return {} unless data.is_a?(Hash)

      subject_for = ->(url) { @piece.candidate_subjects[Array(@piece.candidate_urls).index(url)] }
      pattern_for = ->(url) { @piece.candidate_patterns[Array(@piece.candidate_urls).index(url)] }

      ranking = Array(data["ranking"]).filter_map do |entry|
        next unless entry.is_a?(Hash)

        url = @urls[entry["index"].to_i - 1]
        next if url.nil?

        { "index" => @urls.index(url) + 1, "url" => url, "subject" => subject_for.call(url),
          "pattern" => pattern_for.call(url), "verdict" => entry["verdict"].to_s,
          "reason" => entry["reason"].to_s }
      end
      finalists = Array(data["recommended_finalists"]).filter_map { |i| @urls[i.to_i - 1] }
                                                       .uniq.first(MAX_FINALISTS)
      chosen = @urls[data["recommended_chosen"].to_i - 1]

      { "reasoning" => data["reasoning"].to_s, "finalists" => finalists, "chosen" => chosen,
        "ranking" => ranking }
    end

    def prompt
      <<~P
        You are advising a human on culling a batch of #{@urls.size} generated wall-art print
        candidates. Each candidate was generated from a subject and a scene pattern.

        For every candidate, decide a verdict — keep, borderline, or drop — and give a one-sentence
        reason. Judge on: (a) how well it reads as the locked style, (b) how faithfully it depicts
        its intended subject, and (c) its merit as a wall-art print. Then recommend at most
        #{MAX_FINALISTS} finalists and the single best candidate to choose. Do not recommend more
        finalists than the cap.
      P
    end
  end
end
