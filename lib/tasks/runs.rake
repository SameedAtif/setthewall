namespace :runs do
  desc "Backfill run_steps from PipelineRunRecord#step_results (idempotent)"
  task backfill_cells: :environment do
    result_to_cell = { "ok" => "done", "awaiting_human" => "awaiting_human", "failed" => "failed" }

    backfilled = 0
    created    = 0

    PipelineRunRecord.find_each do |run|
      next if run.run_steps.exists?

      seen = {}
      Array(run.step_results).each_with_index do |entry, index|
        step_id = entry["step_id"]
        next if step_id.blank? || seen[step_id]

        seen[step_id] = true
        run.run_steps.create!(
          step_id: step_id,
          position: index,
          status: result_to_cell.fetch(entry["status"].to_s, "pending"),
          output: entry["data"] || {},
          message: entry["message"],
          verdict: entry["verdict"],
          disposition: entry["disposition"],
          finished_at: entry["at"]
        )
        created += 1
      end

      backfilled += 1
    end

    puts "Backfilled #{created} cell(s) across #{backfilled} run(s)."
  end
end
