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

  # A1's reference images with a flag for whether C1 currently uses each one. `included` reflects
  # the C1 cell's pending override if set, otherwise the effective (close-up + in-situ) set.
  def c1_reference_options(run, step)
    a1 = Array(run.step_results).find { |r| r["step_id"] == "A1" }
    images = Array(a1&.dig("data", "candidates", "images"))
             .select { |i| i.is_a?(Hash) && i["url"].present? }
    current = (step.context_override["reference_images"].presence ||
               Array(Context::Assembler.for("C1", run)[:reference_images]))

    images.map do |image|
      { url: image["url"], src: image["url"], included: current.include?(image["url"]),
        label: "#{image['shot_type']} · #{image['source_name']}" }
    end
  rescue StandardError
    []
  end

  # A browser-loadable src for a candidate image: remote URLs pass through; local files under the
  # app are served through MediaController.
  def reference_image_src(url)
    value = url.to_s
    return value if value.match?(%r{\Ahttps?://}i)

    absolute = File.expand_path(value, Rails.root.to_s)
    media_path(Pathname.new(absolute).relative_path_from(Rails.root).to_s)
  rescue StandardError
    value
  end

  # Render the dossier markdown as sanitized HTML.
  def render_markdown(text)
    return "" if text.blank?

    html = Kramdown::Document.new(text.to_s, input: "GFM").to_html
    sanitize(html, tags: %w[h1 h2 h3 h4 h5 h6 p ul ol li strong em code pre blockquote a img br hr],
                    attributes: %w[href src alt title])
  end
end
