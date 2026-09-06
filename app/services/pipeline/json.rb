module Pipeline
  # Robustly turns an LLM response into a Hash. Qwen's compatible-mode endpoint honors
  # `response_format` inconsistently, so a schema'd call can come back as a raw object, a
  # markdown-fenced object, prose-wrapped JSON, or nothing at all. Normalize to a Hash (or {}) so
  # callers can index the result without crashing on a String, Array, or nil.
  module Json
    module_function

    def normalize(content)
      return content if content.is_a?(Hash)
      return {} if content.blank?

      parsed = parse(content.to_s) || parse(extract_object(content.to_s))
      return parsed if parsed.is_a?(Hash)

      Rails.logger.warn("[Pipeline::Json] no valid JSON object in: #{content.to_s.truncate(300).inspect}")
      {}
    end

    def parse(text)
      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end

    # Locates the outermost JSON object between the first `{` and the last `}` — strips any prose
    # before/after it and ```json … ``` fences.
    def extract_object(text)
      text = text.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "").strip
      open = text.index("{")
      close = text.rindex("}")
      return "" unless open && close && close > open

      text[open..close]
    end
  end
end
