module Workflow
  # Module 08 — Decision Manual. Loads decision_rules.yml and enforces the legality matrix so the
  # gate-closing path (the human review UI, or module 09's conductor) is bounded by the rule file
  # rather than by prose. Verdicts classify a paused step; dispositions are what a reviewer may
  # answer; tiers govern who may close a gate.
  class DecisionRules
    class IllegalDisposition < StandardError; end

    # Mirror of module 08 §5.1. Kept as a single reviewable constant rather than scattered through
    # the YAML; move it into decision_rules.yml if it ever needs per-step reasoning.
    TIERS = {
      "A_IDEATE" => 1, "B1" => 1, "B2" => 1, "B4" => 1, "B5" => 1, "C1" => 1,
      "A6" => 1, "A7" => 1,
      "P2_2a" => 1, "P2_2b" => 1, "P2_2c" => 1, "P2_2d" => 1, "P2_2e" => 1,
      "P2_4" => 1, "P2_4b" => 1, "P3_1" => 1, "P3_3" => 1, "P3_4" => 1, "P3_8" => 1,
      "A1" => 2, "A2" => 2, "A3" => 2, "A4" => 2, "B3" => 2, "B6" => 2,
      "C2" => 2, "C2_finalists" => 2, "P2_1" => 2, "P2_3" => 2, "P2_5" => 2, "P2_6" => 2,
      "P3_1b" => 2, "P3_2" => 2, "P3_5" => 2, "P3_6" => 2,
      "A0" => 3, "A1b" => 3, "A5" => 3, "B0" => 3, "B7" => 3, "C2_chosen" => 3,
      "P2_0" => 3, "P2_7" => 3, "P3_7" => 3
    }.freeze

    def self.rules = KnowledgeBase::RuleSet.load("decision_rules").rules

    def self.verdict_ids = rules["verdicts"].keys
    def self.disposition_ids = rules["dispositions"].keys

    # Which dispositions a reviewer may take for a step's verdict. A step-level
    # `on_<verdict>.legal` list overrides the global matrix (e.g. P2_3's approve-by-note
    # exception to SR2).
    def self.legal_dispositions(step_id:, verdict:)
      override = rules.dig("steps", step_id, "on_#{verdict}", "legal")
      return Array(override) if override

      Array(rules.dig("legality", verdict))
    end

    def self.tier_for(step_id)
      TIERS.fetch(step_id.to_s) { raise IllegalDisposition, "unknown step #{step_id.inspect} (no tier)" }
    end

    def self.gated_step_ids = rules["steps"].select { |_id, step| step["gate"] == true }.keys

    def self.rewind_to(step_id)
      Array(rules.dig("steps", step_id, "rewind_to")).compact
    end

    # Maps a step result (plus optional QA findings) to a verdict. This is the "derived from the
    # step's own exit conditions" path from module 08 §2; the findings-based path layers on top in
    # module 09. `recommended_action` is the step's own signal: return_to_a1 → unresolved_input,
    # reconsider → contradicted, confirm → clean (or flagged when an advisory finding is present).
    def self.verdict_for(step_id:, result:, findings: [])
      return "blocked" if findings.any? { |f| f.respond_to?(:blocking?) && f.blocking? }
      return "blocked" if result.respond_to?(:failed?) && result.failed?

      case recommended_action(result)
      when "return_to_a1" then "unresolved_input"
      when "reconsider"   then "contradicted"
      when "confirm"      then findings.any? { |f| f.respond_to?(:advisory?) && f.advisory? } ? "flagged" : "clean"
      else "clean"
      end
    end

    # The single enforcement point. Bounded by the matrix (SR1), tiers (SR12), citations (SR11),
    # and the mandatory-field rules (S3/S4). Raises IllegalDisposition on any violation.
    def self.validate_disposition!(step_id:, verdict:, disposition:, reviewer_kind: "human", payload: {})
      legal = legal_dispositions(step_id: step_id, verdict: verdict.to_s)
      unless legal.include?(disposition.to_s)
        raise IllegalDisposition,
              "#{step_id} verdict=#{verdict} forbids #{disposition} (legal: #{legal.join(', ')})"
      end

      if reviewer_kind.to_s == "agent" && tier_for(step_id) == 3
        raise IllegalDisposition, "#{step_id} is Tier 3 — an agent may not close it (SR12)."
      end

      if reviewer_kind.to_s == "agent" && Array(payload[:citations]).empty?
        raise IllegalDisposition, "#{step_id} agent disposition carries no citation (SR11)."
      end

      if verdict.to_s == "flagged" && disposition.to_s == "approve" && payload[:acceptance_note].to_s.empty?
        raise IllegalDisposition, "flagged approve requires an acceptance_note (S3)."
      end

      if verdict.to_s == "contradicted" && disposition.to_s == "edit" && payload[:override_reason].to_s.empty?
        raise IllegalDisposition, "contradicted edit requires an override_reason (S4)."
      end

      true
    end

    def self.recommended_action(result)
      return nil unless result.respond_to?(:data)

      data = result.data || {}
      data[:recommended_action] || data["recommended_action"]
    end
    private_class_method :recommended_action
  end
end
