module Agents
  # A QA finding is a citation + a claim + a severity. Agents return findings; they never return
  # dispositions. Module 08's DecisionRules maps findings to verdicts and dispositions.
  Finding = Struct.new(:severity, :claim, :citations, :payload, keyword_init: true) do
    def blocking? = severity == "blocking"
    def advisory? = severity == "advisory"
    def pass?     = severity == "pass"
  end

  class Base
    class << self
      attr_reader :agent_id, :covers

      def agent(id:, covers:)
        @agent_id = id
        @covers   = Array(covers)
      end
    end

    def initialize(run:, step_id:, result:, context:, role: "proposer")
      @run = run
      @step_id = step_id
      @result = result
      @context = context
      @role = role
    end

    def self.call(...) = new(...).call

    def call
      findings = Array(evaluate)
      raise "#{self.class.agent_id} returned no findings for #{@step_id}" if findings.empty?

      findings.each { |f| persist!(f) }
      findings
    end

    private

    # Subclasses implement this and return one or more Finding.
    def evaluate = raise NotImplementedError

    # The step result's data, deep-stringified so agents can index it with string keys regardless
    # of whether the step stored it with symbol keys (in-memory StepResult) or string keys (jsonb).
    def data
      raw = @result.respond_to?(:data) ? @result.data : @result
      (raw || {}).deep_stringify_keys
    end

    def rules(name) = KnowledgeBase::RuleSet.load(name)
    def qa_rules    = rules("qa_rules").rules.fetch(self.class.agent_id)

    def pass(claim, citations) = Finding.new(severity: "pass", claim:, citations:, payload: {})
    def advisory(claim, citations, payload = {}) =
      Finding.new(severity: "advisory", claim:, citations:, payload:)
    def blocking(claim, citations, payload = {}) =
      Finding.new(severity: "blocking", claim:, citations:, payload:)

    # A citation is a path into a rule file, not a sentence. EvidenceQa re-resolves these.
    def cite(rule_path, claim: nil)
      { "rule_path" => rule_path, "claim" => claim }
    end

    def persist!(finding)
      QaFinding.create!(
        pipeline_run_record: @run, step_id: @step_id, agent_id: self.class.agent_id,
        role: @role, severity: finding.severity, claim: finding.claim,
        citations: finding.citations, payload: finding.payload
      )
    end
  end
end
