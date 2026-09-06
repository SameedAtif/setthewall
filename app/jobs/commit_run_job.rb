class CommitRunJob < ApplicationJob
  queue_as :default

  # The only place a run is replayed in committed mode. Module 09 §9: moving staging files into
  # knowledge_base/, the git commit, and the Etsy publish all happen here — never in a speculative
  # run. (The full staging→KB replay is a follow-up; this marks the run committed under the guard.)
  def perform(run_id:)
    run = PipelineRunRecord.find_by!(run_id: run_id)
    Workflow::RunMode.with("committed", run_id: run_id) do
      run.update!(mode: "committed", status: "committed")
    end
  end
end
