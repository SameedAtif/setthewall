class ProcessPieceJob < ApplicationJob
  queue_as :default

  # step_id: the next step to run for this piece
  # context: whatever extra input that step needs (e.g. a human's approved override)
  def perform(piece_id:, step_id:, context: {})
    piece = PieceRecord.find(piece_id)

    # Refuse to run against uncommitted knowledge base — unless the piece already ran with dirty
    # (in which case it stays dirty; don't upgrade it silently).
    unless piece.dirty_run?
      begin
        Workflow::PreflightCheck.call!
      rescue Workflow::DirtyKnowledgeBaseError => e
        piece.update!(status: "failed", last_error: e.message)
        return
      end
    end

    result = Workflow::StepDispatcher.call(step_id: step_id, piece: piece,
                                           context: context.deep_symbolize_keys)

    return unless result.ok?

    # Advance to the next step if there is one.
    if (next_step = Workflow::PipelineRun.next_step_after(step_id, piece))
      ProcessPieceJob.perform_later(piece_id: piece.id, step_id: next_step)
    end
  end
end
