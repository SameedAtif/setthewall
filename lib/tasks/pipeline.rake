namespace :pipeline do
  desc "Run one piece through the daily pipeline. Usage: rake pipeline:daily style=japandi-v1 scene=behind_sofa_light_neutral"
  task daily: :environment do
    style = ENV.fetch("style")
    scene = ENV.fetch("scene")
    piece = Workflow::PipelineRun.start_daily(style_slug: style, scene_spec_id: scene)
    puts "Started daily pipeline. PieceRecord ##{piece.id}, kb_version=#{piece.kb_version}"
    puts "Ensure a Solid Queue worker is running (`bin/jobs`) to process the steps."
    puts "Run `bin/rails pipeline:status piece=#{piece.id}` to watch."
  end

  desc "Survey style candidates before committing to one. Usage: rake pipeline:ideate_styles [direction='calm and neutral'] [count=5]"
  task ideate_styles: :environment do
    context = {}
    context[:direction] = ENV["direction"] if ENV["direction"].present?
    context[:candidate_count] = ENV["count"].to_i if ENV["count"].present?

    result = Workflow::StepDispatcher.call(step_id: "A_IDEATE", piece: nil, context: context)
    puts result.message
    puts JSON.pretty_generate(result.data[:candidates])
  end

  desc "Kick off Track A for a new style. Usage: rake pipeline:track_a style_slug=japandi-v1 style_name=Japandi"
  task track_a: :environment do
    slug = ENV.fetch("style_slug")
    name = ENV.fetch("style_name")
    run = Workflow::TrackRunner.start(track: "track_a", style_slug: slug, style_name: name)
    puts "Track A started. TrackRun ##{run.id} at step #{run.current_step}, status=#{run.status}."
    puts "Open gates at localhost:3000/reviews; resume with pipeline:resume gate=<id>."
  end

  desc "Kick off Track B for a scene template. Usage: rake pipeline:track_b style_slug=japandi-v1 scene=behind_sofa_light_neutral"
  task track_b: :environment do
    slug  = ENV.fetch("style_slug")
    scene = ENV.fetch("scene")
    run = Workflow::TrackRunner.start(
      track: "track_b", style_slug: slug, scene_template_id: scene,
      scene_image: "scene_templates/assets/#{scene}.png"
    )
    puts "Track B started. TrackRun ##{run.id} at step #{run.current_step}, status=#{run.status}."
    puts "Open gates at localhost:3000/reviews; resume with pipeline:resume gate=<id>."
  end

  desc "Resume a paused piece or track by closing its open gate. Usage: rake pipeline:resume gate=42 decision=approved [reviewer_edits='{\"key\":\"value\"}']"
  task resume: :environment do
    gate = HumanGate.find(ENV.fetch("gate"))
    decision = ENV.fetch("decision", "approved")
    edits = ENV["reviewer_edits"].present? ? JSON.parse(ENV["reviewer_edits"]) : {}
    notes = ENV["notes"]

    gate.update!(
      status: decision,
      reviewer_edits: edits,
      reviewer_decision: (decision == "edited" ? edits.to_json : gate.agent_proposal),
      notes: notes,
      closed_at: Time.current
    )

    if gate.track_run.present?
      Workflow::TrackRunner.resume(gate)
      puts "Gate ##{gate.id} → #{decision}. Track resumed; TrackRun ##{gate.track_run_id} now at step #{gate.track_run.reload.current_step} (#{gate.track_run.status})."
    else
      ResumePieceJob.perform_later(gate_id: gate.id) if %w[approved edited].include?(decision)
      puts "Gate ##{gate.id} → #{decision}. Resume job enqueued."
    end
  end

  desc "Show status of a piece. Usage: rake pipeline:status piece=42"
  task status: :environment do
    piece = PieceRecord.find(ENV.fetch("piece"))
    puts "Piece ##{piece.id}"
    puts "  status:      #{piece.status}"
    puts "  current_step: #{piece.current_step}"
    puts "  kb_version:  #{piece.kb_version}#{' (DIRTY)' if piece.dirty_run?}"
    puts "  style/scene: #{piece.style_spec_slug}/#{piece.scene_spec_id}"
    puts "  last_error:  #{piece.last_error}" if piece.last_error.present?
    puts "  open gate:   ##{piece.open_gate&.id || '(none)'} (step=#{piece.open_gate&.step_id})"
    puts "  gates total: #{piece.human_gates.count} (#{piece.human_gates.closed.count} closed)"
  end

  desc "Show status of a Track A/B run. Usage: rake pipeline:track_status run=42"
  task track_status: :environment do
    run = TrackRun.find(ENV.fetch("run"))
    puts "TrackRun ##{run.id} (#{run.track})"
    puts "  style:       #{run.style_slug}"
    puts "  scene:       #{run.scene_template_id || '(n/a)'}"
    puts "  status:      #{run.status}"
    puts "  current_step: #{run.current_step}"
    puts "  last_error:  #{run.last_error}" if run.last_error.present?
    puts "  open gate:   ##{run.human_gates.open.order(:opened_at).last&.id || '(none)'} (step=#{run.human_gates.open.last&.step_id})"
    puts "  gates total: #{run.human_gates.count} (#{run.human_gates.closed.count} closed)"
  end
end
