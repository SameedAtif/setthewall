module Llm
  # Produces the human-readable paragraph for a notebook cell. LLM-written at step completion, with
  # a deterministic fallback so a failed/slow model call never blocks the pipeline.
  class CellSummarizer
    def self.call(run_step:) = new(run_step: run_step).call

    def initialize(run_step:) = @step = run_step

    def call
      content = RubyLLM.chat(model: Pipeline::TEXT_MODEL).ask(prompt).content
      text = content.to_s.strip
      text.presence || fallback
    rescue StandardError
      fallback
    end

    private

    def prompt
      <<~PROMPT
        Summarize this pipeline step in 2-5 plain sentences for an operator reviewing a notebook.
        Say what the step did, what it found, and what (if anything) needs the operator's attention.
        Do not include raw JSON, keys, or a preamble.

        Step: #{@step.step_id}
        Status: #{@step.status}
        Step notes: #{@step.message}
        Step result: #{(@step.output || {}).to_json.truncate(2000)}
      PROMPT
    end

    def fallback
      parts = []
      parts << @step.message.to_s.strip if @step.message.present?

      data = (@step.output || {}).except("prompt", "brief", "searches", "search", "prompts")
      if data.present?
        parts << data.map { |key, value| "#{key.to_s.humanize}: #{value.to_s.truncate(160)}" }.join(" · ")
      end

      parts.reject(&:blank?).join("\n\n").presence || "#{@step.step_id} #{@step.status}."
    end
  end
end
