module Pipeline
  # Default models per mechanism. Override per-step in the step class if needed.
  # When QWEN_API_KEY is set, both default to the Qwen model; otherwise fall back
  # to the (placeholder) Anthropic model ids.
  VISION_MODEL = ENV.fetch("PIPELINE_VISION_MODEL", ENV.fetch("QWEN_MODEL", "claude-sonnet-5"))
  TEXT_MODEL   = ENV.fetch("PIPELINE_TEXT_MODEL",   ENV.fetch("QWEN_MODEL", "claude-sonnet-5"))

  # Qwen's reasoning models will happily "think" for 10+ minutes on a content prompt (streaming
  # empty-content deltas the whole time), which the stall watchdog can't detect as a stall. Cap the
  # thinking budget so generation is bounded while thinking stays ENABLED. Set to 0 to leave it
  # unbounded.
  QWEN_THINKING_BUDGET = ENV.fetch("QWEN_THINKING_BUDGET", "2048").to_i

  # Root of the version-controlled knowledge base.
  KB_ROOT = Rails.root.join("knowledge_base")
end
