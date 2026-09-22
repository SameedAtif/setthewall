module ImageGeneration
  class Adapter
    # Every concrete adapter implements these three methods, nothing else.
    def name = raise(NotImplementedError)

    # prompt: String — the image-gen prompt built by C1's synthesis step
    # n:      Integer — how many candidates to produce this call (respects batch cap in caller)
    # style_reference: optional Array<String> of reference image URLs, if the provider supports it
    def generate(prompt:, n:, style_reference: []) = raise(NotImplementedError)

    # Best-effort estimate for logging into PieceRecord.step_log. Fine to hard-code a per-image
    # constant per provider — this is for cost tracking, not billing.
    def estimated_cost_usd(n:) = raise(NotImplementedError)

    def self.build
      case ENV.fetch("IMAGE_GEN_PROVIDER", "manual")
      when "manual"    then ManualAdapter.new
      when "replicate" then ReplicateAdapter.new
      when "gemini"    then GeminiAdapter.new
      else raise GenerationError, "Unknown IMAGE_GEN_PROVIDER=#{ENV['IMAGE_GEN_PROVIDER']}"
      end
    end
  end
end
