class ExecuteRunJob < ApplicationJob
  queue_as :default

  # mode: "next" (one cell), "to_decision" (run until a gate), "all" (run everything),
  #       "rerun" (a specific cell + stales downstream)
  def perform(run_id:, mode: "next", run_step_id: nil)
    run = PipelineRunRecord.find(run_id)

    case mode.to_s
    when "all"         then Workflow::CellRunner.run_all(run)
    when "to_decision" then Workflow::CellRunner.run_until_gate(run)
    when "rerun"       then Workflow::CellRerunner.call(run_step: RunStep.find(run_step_id))
    else                    Workflow::CellRunner.run_next(run)
    end
  end
end
