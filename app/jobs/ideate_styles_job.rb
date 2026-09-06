class IdeateStylesJob < ApplicationJob
  queue_as :default

  # direction: optional loose steer; count: optional candidate count (capped by the rule file)
  def perform(direction: nil, count: nil)
    survey = IdeationSurvey.create!(direction: direction, candidate_count: count,
                                    status: "running", progress: "queued")

    context = {
      on_progress: ->(message) { survey.update_column(:progress, message) }
    }
    context[:direction] = direction if direction.present?
    context[:candidate_count] = count if count.present?

    Rails.logger.info("[IdeateStylesJob #{survey.id}] started")

    result = Workflow::StepDispatcher.call(step_id: "A_IDEATE", piece: nil, context: context)

    survey.update!(
      status: result.failed? ? "failed" : "complete",
      progress: result.failed? ? "failed" : "done",
      candidates: result.data[:candidates] || [],
      weak_candidates: result.data[:weak_candidates] || [],
      survey_notes: result.data[:survey_notes],
      last_error: result.failed? ? result.message : nil
    )

    Rails.logger.info("[IdeateStylesJob #{survey.id}] #{result.failed? ? 'failed' : 'complete'} " \
                      "(#{survey.candidates.size} candidates)")
  rescue StandardError => e
    survey&.update!(status: "failed", progress: "failed", last_error: "#{e.class}: #{e.message}")
    Rails.logger.error("[IdeateStylesJob #{survey&.id}] failed: #{e.class}: #{e.message}")
  end
end
