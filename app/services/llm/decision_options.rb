module Llm
  # Generates concrete next-step options for a paused notebook cell, constrained to the legal
  # dispositions for that step/verdict. Falls back to deterministic options if the model fails or
  # returns nothing usable, so a gate always has something actionable.
  class DecisionOptions
    Option = Struct.new(:label, :description, :intent, :notes, :edits, keyword_init: true) do
      def to_h
        { "label" => label, "description" => description, "intent" => intent,
          "notes" => notes, "edits" => edits || {} }.compact
      end
    end

    MAX_OPTIONS = 4

    def self.call(run_step:) = new(run_step: run_step).call

    def initialize(run_step:) = @step = run_step

    def call
      content = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                      .with_schema(Schemas::DecisionOptionsSchema)
                      .ask(prompt)
                      .content
      parsed = Pipeline::Json.normalize(content)
      options = Array(parsed["options"]).filter_map { |option| build(option) }.first(MAX_OPTIONS)
      options.presence || self.class.fallback_for(@step)
    rescue StandardError
      self.class.fallback_for(@step)
    end

    # Deterministic, LLM-free options from the legal dispositions. Used as a fallback and to fill
    # in legacy cells that paused before options existed.
    def self.fallback_for(run_step)
      verdict = run_step.verdict.presence || "clean"
      legal = Workflow::DecisionRules.legal_dispositions(step_id: run_step.step_id, verdict: verdict)
      legal.map do |intent|
        Option.new(label: label_for(intent), description: description_for(intent, run_step),
                   intent: intent, notes: nil, edits: {}).to_h
      end
    end

    def self.label_for(intent)
      { "approve" => "Approve and continue", "edit" => "Approve with changes",
        "retry" => "Re-run this step", "rewind" => "Go back to an earlier step",
        "abandon" => "Abandon this run" }.fetch(intent, intent.humanize)
    end

    def self.description_for(intent, run_step)
      case intent
      when "approve" then "Accept this result as-is and reveal the next step."
      when "edit"    then "Accept with changes you specify, then reveal the next step."
      when "retry"   then "Run #{run_step.step_id} again from scratch."
      when "rewind"  then "Undo downstream cells and go back."
      when "abandon" then "Stop this run."
      else intent.humanize
      end
    end

    private

    def legal_intents
      @legal_intents ||= self.class.fallback_for(@step).map { |option| option["intent"] }
    end

    def prompt
      <<~PROMPT
        A human is reviewing step #{@step.step_id} of an art-pipeline run. Suggest 3-4 concrete
        next steps they might take. Only use these legal intents: #{legal_intents.join(', ')}.

        Step question/notes: #{@step.message}
        Step status: #{@step.status}
        Step result (truncated): #{(@step.output || {}).to_json.truncate(2000)}

        Return one option per likely action, most-likely first. Keep labels short and specific to
        this step's actual result. Use `edits_json` only for an "edit" option; otherwise "{}".
      PROMPT
    end

    def build(option)
      intent = option["intent"].to_s.strip.downcase
      return nil unless legal_intents.include?(intent)

      Option.new(label: option["label"].to_s.presence || self.class.label_for(intent),
                 description: option["description"].to_s.presence,
                 intent: intent, notes: option["notes"].to_s.presence,
                 edits: parse_edits(option["edits_json"])).to_h
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
