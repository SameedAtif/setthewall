namespace :run do
  desc "Speculative end-to-end run. Writes nothing outside tmp/. rake run:speculative style=x scene=y"
  task speculative: :environment do
    run = Agents::Conductor.run_speculative(style_slug: ENV.fetch("style"),
                                            scene_spec_id: ENV.fetch("scene"))
    puts "Run #{run.run_id} → #{run.status}"
    puts "Escalations: #{run.escalations.size}"
    puts "Dossier: bin/rails run:dossier id=#{run.run_id}"
  end

  desc "Print a run's dossier. rake run:dossier id=run_20260902_a3f1"
  task dossier: :environment do
    puts PipelineRunRecord.find_by!(run_id: ENV.fetch("id")).dossier_markdown
  end

  desc "Approve and commit a reviewed run. rake run:commit id=... notes='...'"
  task commit: :environment do
    run = PipelineRunRecord.find_by!(run_id: ENV.fetch("id"))
    abort "Run is #{run.status}, expected awaiting_dossier_review." unless run.status == "awaiting_dossier_review"
    run.update!(status: "approved", reviewed_at: Time.current, reviewer_notes: ENV["notes"])
    CommitRunJob.perform_now(run_id: run.run_id)
    puts "Committed. Listing: #{run.reload.piece_record&.etsy_listing_id}"
  end

  desc "Rerun from a step with guidance. rake run:rerun id=... step=A1 notes='...'"
  task rerun: :environment do
    RerunFromStepJob.perform_now(run_id: ENV.fetch("id"), step_id: ENV.fetch("step"),
                                 guidance: ENV["notes"])
  end
end
