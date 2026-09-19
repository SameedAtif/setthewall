module ApplicationHelper
  # Tailwind classes for a status badge.
  def status_color(status)
    case status
    when "complete", "done"  then "bg-green-100 text-green-800"
    when "awaiting_human"    then "bg-amber-100 text-amber-800"
    when "failed"            then "bg-red-100 text-red-800"
    when "running"           then "bg-blue-100 text-blue-800"
    when "queued"            then "bg-sky-100 text-sky-800"
    when "stale"             then "bg-yellow-100 text-yellow-800"
    when "skipped"           then "bg-gray-100 text-gray-500"
    else "bg-gray-100 text-gray-700"   # pending, open, etc.
    end
  end

  # Tailwind text color for a log level.
  def log_level_class(level)
    case level.to_s
    when "error" then "text-red-400"
    when "warn"  then "text-yellow-300"
    else "text-emerald-300"
    end
  end

  # Human title for a pipeline step, from the canonical registry.
  def run_step_title(step_id)
    Dossier::Builder.step_titles[step_id.to_s] || step_id.to_s
  end

  # Render the dossier markdown as sanitized HTML.
  def render_markdown(text)
    return "" if text.blank?

    html = Kramdown::Document.new(text.to_s, input: "GFM").to_html
    sanitize(html, tags: %w[h1 h2 h3 h4 h5 h6 p ul ol li strong em code pre blockquote a img br hr],
                    attributes: %w[href src alt title])
  end
end
