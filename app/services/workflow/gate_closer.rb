module Workflow
  # Records a gate closure with its verdict, disposition, reviewer kind, and citations. Bounded by
  # module 08 (DecisionRules.validate_disposition!) at every call site; the closer itself only
  # writes the record so the audit trail is uniform whether the reviewer is a human or an agent.
  class GateCloser
    def self.call(run:, step_id:, verdict:, disposition:, reviewer_kind:, findings:)
      HumanGate.create!(
        piece_record: run.piece_record,
        step_id: step_id,
        gate_kind: step_id.parameterize.underscore,
        status: status_for(disposition),
        verdict: verdict,
        reviewer_kind: reviewer_kind,
        citations: findings.flat_map(&:citations),
        agent_proposal: "{}",
        context_snapshot: {},
        notes: findings.map(&:claim).join(" | "),
        opened_at: Time.current,
        closed_at: Time.current
      )
    end

    def self.status_for(disposition)
      case disposition.to_s
      when "approve" then "approved"
      when "edit"    then "edited"
      else "rejected"   # retry, rewind, abandon all map to rejected (module 08 §3)
      end
    end
  end
end
