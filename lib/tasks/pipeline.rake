namespace :pipeline do
  desc "Run one piece through the daily pipeline. Usage: rake pipeline:daily style=japandi-v1 scene=behind_sofa_light_neutral"
  task daily: :environment do
    style = ENV.fetch("style")
    scene = ENV.fetch("scene")
    piece = Workflow::PipelineRun.start_daily(style_slug: style, scene_spec_id: scene)
    puts "Started daily pipeline. PieceRecord ##{piece.id}, kb_version=#{piece.kb_version}"
    puts "Run `bin/rails pipeline:status piece=#{piece.id}` to watch."
  end

  desc "Kick off Track A for a new style. Usage: rake pipeline:track_a style_slug=japandi-v1 style_name=Japandi"
  task track_a: :environment do
    slug = ENV.fetch("style_slug")
    name = ENV.fetch("style_name")
    context = { style_slug: slug, style_name: name }
    result = Workflow::StepDispatcher.call(step_id: "A0", piece: nil, context: context)
    puts "A0 -> #{result.status}. #{result.message}"
    puts "Findings JSON in the returned data; run subsequent A-steps via the console once A0 human-gate closes."
  end

  desc "Kick off Track B for a scene template. Usage: rake pipeline:track_b style_slug=japandi-v1 scene=behind_sofa_light_neutral"
  task track_b: :environment do
    slug  = ENV.fetch("style_slug")
    scene = ENV.fetch("scene")
    context = {
      style_slug: slug,
      scene_template_id: scene,
      scene_image: "scene_templates/assets/#{scene}.png"
    }
    result = Workflow::StepDispatcher.call(step_id: "B0", piece: nil, context: context)
    puts "B0 -> #{result.status}. #{result.message}"
  end

  desc "Resume a paused piece by closing its open gate. Usage: rake pipeline:resume gate=42 decision=approved"
  task resume: :environment do
    gate = HumanGate.find(ENV.fetch("gate"))
    gate.update!(status: ENV.fetch("decision", "approved"),
                 reviewer_decision: gate.agent_proposal,
                 closed_at: Time.current)
    ResumePieceJob.perform_later(gate_id: gate.id)
    puts "Gate ##{gate.id} → #{gate.status}. Resume job enqueued."
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
end
