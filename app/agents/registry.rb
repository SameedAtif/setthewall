module Agents
  class Registry
    SPECIALISTS = [ResearchQa, AxisQa, ImageQa, PlacementQa, ListingQa, CustomerSafetyQa].freeze

    def self.for(step_id) = SPECIALISTS.select { |a| a.covers.include?(step_id) }

    # Fail loudly rather than letting a step slip through unreviewed. Tier 3 steps are escalated to
    # the human (never QA'd), so they are excluded from the coverage check.
    def self.validate_coverage!(gated_step_ids = Workflow::DecisionRules.gated_step_ids)
      qa_steps = gated_step_ids.reject { |id| Workflow::DecisionRules.tier_for(id) == 3 }
      uncovered = qa_steps.reject { |id| self.for(id).any? }
      raise "Steps with no QA agent: #{uncovered.inspect}" if uncovered.any?

      true
    end
  end
end
