module Llm
  # Turns a reviewer's plain-English feedback on a notebook cell into a structured, rule-bounded
  # decision: intent (a Workflow::DecisionRules disposition), human-readable notes, a reason, and
  # any field-level edits. Never mutates the run — application is Workflow::GateApplier's job.
  class FeedbackInterpreter
    class IllegalIntent < StandardError; end

    Result = Struct.new(:intent, :notes, :edits, :reason, :raw, keyword_init: true) do
      def approve? = intent == "approve"
      def edit? = intent == "edit"
      def retry? = intent == "retry"
      def rewind? = intent == "rewind"
      def abandon? = intent == "abandon"
    end

    def self.call(run_step:, body:) = new(run_step: run_step, body: body).call

    def initialize(run_step:, body:)
      @step = run_step
      @body = body.to_s
    end

    def call
      content = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                      .with_schema(Schemas::FeedbackInterpretationSchema)
                      .ask(prompt)
                      .content
      build_result(Pipeline::Json.normalize(content))
    end

    # The dispositions a reviewer may choose, constrained to what the step's verdict allows.
    def legal_intents
      @legal_intents ||= begin
        verdict = @step.verdict.presence
        verdict ? Workflow::DecisionRules.legal_dispositions(step_id: @step.step_id, verdict: verdict) \
                : Workflow::DecisionRules.disposition_ids
      end
    end

    private

    def prompt
      <<~PROMPT
        Translate a human reviewer's feedback on one art-pipeline step into a structured decision.
        Do not invent changes the reviewer did not ask for.

        Step: #{@step.step_id}
        Status: #{@step.status}
        Step question/notes: #{@step.message}
        Step result: #{(@step.output || {}).to_json.truncate(2000)}
        Legal decisions for this step: #{legal_intents.join(', ')}

        Reviewer feedback:
        #{@body}

        Choose the single best `intent` from the legal decisions. Put any field/context changes the
        reviewer asked for into `edits_json` as a JSON object, or "{}" if none. Write a short
        `notes` summary, and a `reason` (used as the override reason when editing a contradicted
        result).
      PROMPT
    end

    def build_result(parsed)
      intent = parsed["intent"].to_s.strip.downcase
      unless legal_intents.include?(intent)
        raise IllegalIntent,
              "Feedback mapped to #{intent.inspect}, which is not legal for #{@step.step_id} " \
              "(legal: #{legal_intents.join(', ')}). Please rephrase."
      end

      Result.new(
        intent: intent,
        notes: parsed["notes"].to_s.presence,
        edits: parse_edits(parsed["edits_json"]),
        reason: parsed["reason"].to_s.presence,
        raw: parsed
      )
    end

    def parse_edits(raw)
      return {} if raw.blank?
      return raw.deep_stringify_keys if raw.is_a?(Hash)

      parsed = JSON.parse(raw.to_s)
      parsed.is_a?(Hash) ? parsed.deep_stringify_keys : {}
    rescue JSON::ParserError
      {}
    end
  end
end
