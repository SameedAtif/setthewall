module ImageGeneration
  class ManualAdapter < Adapter
    def name = "manual"

    # Writes the prompt to a file and returns immediately with a needs_human flag in the
    # Result. The C1 step surfaces this to the review UI (module 06), where you paste back
    # the image URLs after running the prompt yourself in Midjourney/ChatGPT/anywhere.
    def generate(prompt:, n:, style_reference: [])
      out_dir = Rails.root.join("tmp", "manual_gen_prompts")
      out_dir.mkpath
      file = out_dir.join("prompt_#{Time.current.to_i}.txt")
      file.write(<<~TXT)
        # Manual image-generation prompt
        # Count requested: #{n}
        # Style reference URLs (optional):
        #{style_reference.map { |u| "#     #{u}" }.join("\n")}

        #{prompt}
      TXT

      Result.new(urls: [], provider: "manual", model: "manual",
                 estimated_cost_usd: 0.0,
                 raw_response: { pending: true, prompt_file: file.to_s, n_requested: n })
    end

    def estimated_cost_usd(n:) = 0.0
  end
end
