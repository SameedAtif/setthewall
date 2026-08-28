module Pipeline
  # Default models per mechanism. Override per-step in the step class if needed.
  # When QWEN_API_KEY is set, both default to the Qwen model; otherwise fall back
  # to the (placeholder) Anthropic model ids.
  VISION_MODEL = ENV.fetch("PIPELINE_VISION_MODEL", ENV.fetch("QWEN_MODEL", "claude-sonnet-5"))
  TEXT_MODEL   = ENV.fetch("PIPELINE_TEXT_MODEL",   ENV.fetch("QWEN_MODEL", "claude-sonnet-5"))

  # Root of the version-controlled knowledge base.
  KB_ROOT = Rails.root.join("knowledge_base")
end
