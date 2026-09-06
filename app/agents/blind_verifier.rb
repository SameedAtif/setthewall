module Agents
  # Module 09 §1.4/§6 — the Tier 2 protocol. The verifier sees the step input and the cited rules,
  # never the proposer's findings. Agreement closes the gate; disagreement escalates. Deliberately
  # no tie-breaker: a third correlated judge converts the one real error detector into a majority
  # vote among correlated judges.
  class BlindVerifier
    Outcome = Struct.new(:agreed, :verifier_findings, :divergence, keyword_init: true)
    RANK = { "pass" => 0, "advisory" => 1, "blocking" => 2 }.freeze

    def self.call(run:, step_id:, result:, context:, proposer_findings:)
      verifier_findings = Registry.for(step_id).flat_map do |klass|
        klass.call(run: run, step_id: step_id, result: result, context: context, role: "verifier")
      end

      p_sev = worst(proposer_findings)
      v_sev = worst(verifier_findings)
      Outcome.new(
        agreed: p_sev == v_sev,
        verifier_findings: verifier_findings,
        divergence: p_sev == v_sev ? nil : { proposer: p_sev, verifier: v_sev }
      )
    end

    def self.worst(findings) = findings.max_by { |f| RANK.fetch(f.severity, 0) }&.severity || "pass"
  end
end
