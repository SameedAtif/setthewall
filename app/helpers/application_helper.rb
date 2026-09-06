module ApplicationHelper
  # Tailwind classes for a status badge.
  def status_color(status)
    case status
    when "complete"          then "bg-green-100 text-green-800"
    when "awaiting_human"    then "bg-amber-100 text-amber-800"
    when "failed"            then "bg-red-100 text-red-800"
    when "running"           then "bg-blue-100 text-blue-800"
    else "bg-gray-100 text-gray-700"   # pending, open, etc.
    end
  end

  # Render a human gate's agent proposal. Steps with a dedicated partial get a structured,
  # readable layout; everything else falls back to pretty-printed JSON.
  def render_agent_proposal(gate, proposal)
    case gate.step_id
    when "A0"
      render partial: "human_gates/proposals/a0", locals: { proposal: proposal }
    else
      tag.pre(JSON.pretty_generate(proposal), class: "bg-gray-50 border rounded p-3 text-sm overflow-auto")
    end
  end

  # Next step in a track's sequence, or nil once the run is done/stopped (module 01c).
  def track_next_step(run)
    return nil unless %w[running awaiting_human].include?(run.status)

    Workflow::TrackRunner.next_step(run.track, run.current_step)
  end

  # Compact "k=v" summary of the style axes already decided for a Track A run.
  def track_a_decisions(run)
    return "" unless run.track == "track_a"

    run.context.slice("mood", "content_type", "frame_form").compact
        .map { |k, v| "#{k}=#{v}" }.join("  ")
  end
end
