module Agents
  # Meta agent. Does not look at pipeline output — it re-resolves every citation every other agent
  # produced, because self-reported grounding is not grounding (SR11). A `rule_path` is
  # "<file>.<dotted.key.path>" and resolves through KnowledgeBase::RuleSet or it does not.
  class EvidenceQa
    def self.call(run:)
      unresolved = []
      run.qa_findings.where(citations_resolved: nil).find_each do |finding|
        ok = Array(finding.citations).all? { |c| resolves?(c["rule_path"]) }
        finding.update!(citations_resolved: ok)
        unresolved << finding unless ok
      end
      unresolved
    end

    def self.resolves?(path)
      return false if path.blank?

      file, *keys = path.to_s.split(".")
      keys.shift if keys.first == "rules"   # "<file>.rules.<dotted.path>"
      data = KnowledgeBase::RuleSet.load(file).rules
      keys.reduce(data) { |acc, k| acc.is_a?(Hash) ? acc[k] : nil }.present?
    rescue StandardError
      false
    end
  end
end
