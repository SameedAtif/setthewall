class ResumePieceJob < ApplicationJob
  queue_as :default

  # gate_id: the HumanGate just closed by the reviewer
  def perform(gate_id:)
    gate  = HumanGate.find(gate_id)
    piece = gate.piece_record

    unless gate.status == "approved" || gate.status == "edited"
      # Rejected — piece stays failed/pending; the reviewer will initiate the next action.
      return
    end

    # Merge the reviewer's decision into the context for the resumed run.
    context = gate.context_snapshot.deep_symbolize_keys
                  .merge(confirmed: true)
                  .merge(gate.reviewer_edits.deep_symbolize_keys)

    # For steps whose completion IS the reviewer's confirmation (A5, B7, C2 chosen, P3_7),
    # re-invoke the same step_id — the step class checks `context[:confirmed]` and completes.
    # For steps that produced a proposal awaiting confirmation (B6 override, P3_2 hero,
    # P3_6 tone), same pattern: re-run with context populated.
    ProcessPieceJob.perform_later(piece_id: piece.id, step_id: gate.step_id, context: context)
  end
end
