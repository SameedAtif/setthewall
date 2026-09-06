class RerunFromStepJob < ApplicationJob
  queue_as :default

  # Records a re-run from a named step with reviewer guidance. (Full invalidation via module 08's
  # graph and resuming the conductor is a follow-up.)
  def perform(run_id:, step_id:, guidance: nil)
    run = PipelineRunRecord.find_by!(run_id: run_id)
    note = "rerun from #{step_id}: #{guidance}".strip
    run.update!(status: "rerunning",
                reviewer_notes: [run.reviewer_notes, note].compact.reject(&:empty?).join("\n"))
  end
end
