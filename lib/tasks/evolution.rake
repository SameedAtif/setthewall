namespace :evolution do
  desc "Refresh performance snapshots for all published pieces. Usage: rake evolution:refresh_stats"
  task refresh_stats: :environment do
    Performance::EtsyStatsFetcher.call(date: Date.current)
    puts "Refreshed snapshots for #{PieceRecord.published.trustworthy.count} published pieces."
  end

  desc "Build the weekly export. Usage: rake evolution:export week_ending=2026-08-24"
  task export: :environment do
    date = ENV["week_ending"] ? Date.parse(ENV["week_ending"]) : Date.current
    result = Performance::WeeklyExport.call(week_ending: date)
    puts "Wrote:"
    puts "  #{result[:markdown_path]}"
    puts "  #{result[:json_path]}"
    puts "Cycle ID: #{result[:cycle_id]}"
    puts "Pieces in window: #{result[:piece_count]}"
    puts "Next: bin/rails evolution:propose cycle=#{result[:cycle_id]}"
  end

  desc "Ask Claude for KB proposals against a cycle. Usage: rake evolution:propose cycle=CYCLE_ID"
  task propose: :environment do
    cycle = ENV.fetch("cycle")
    proposals = KbEvolution::Proposer.call(cycle_id: cycle)
    puts "Claude produced #{proposals.size} proposal(s) for cycle #{cycle}."
    puts "Review at http://localhost:3000/kb_proposals"
  end

  desc "Apply an approved proposal to disk. Usage: rake evolution:apply id=42"
  task apply: :environment do
    p = KbProposal.find(ENV.fetch("id"))
    KbEvolution::Applier.call(proposal: p)
    puts "Applied proposal ##{p.id} to #{p.target_path}."
    puts "Review with: git diff knowledge_base/"
  end
end
