module RunStepOutputHelper
  IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .svg .avif].freeze
  IMAGE_KEYS = %w[image images url urls candidate_urls finalist_urls composite_url photos
                  reference_images image_urls thumbnail thumbnails hero chosen_url].freeze
  VERBATIM_KEYS = %w[prompt prompts brief criteria].freeze

  # Turn a step's structured output into readable sections/tables/paragraphs, with images inline
  # and external links given a sandboxed preview. Everything is built with tag helpers, so text is
  # escaped and only http(s) URLs become links/images.
  def render_step_output(step)
    return "".html_safe if step.output.blank?

    content_tag(:div, class: "step-output mt-2 space-y-3 text-sm text-gray-800",
                     data: { lightbox_scope: true }) do
      render_output_value(step.output, depth: 0, key: nil, step_id: step.step_id)
    end
  end

  private

  def render_output_value(value, depth:, key: nil, step_id: nil)
    case value
    when Hash          then render_output_hash(value, depth: depth, step_id: step_id)
    when Array         then render_output_array(value, depth: depth, key: key, step_id: step_id)
    when String        then render_output_string(value, key: key)
    when Numeric, TrueClass, FalseClass then content_tag(:span, value.to_s)
    when NilClass      then content_tag(:span, "—", class: "text-gray-400")
    else content_tag(:code, value.inspect, class: "text-xs")
    end
  end

  def render_output_hash(hash, depth:, step_id:)
    return content_tag(:span, "{}", class: "text-gray-400") if hash.empty?

    content_tag(:div, class: "space-y-2") do
      safe_join(hash.map { |key, value| render_output_member(key.to_s, value, depth: depth, step_id: step_id) })
    end
  end

  # Every section becomes its own collapsible block, matching the prompt/raw-JSON pattern. Sections
  # that are just images open by default so the candidates are visible without a click.
  def render_output_member(key, value, depth:, step_id:)
    content_tag(:details, class: depth.positive? ? "ml-3 border-l border-gray-200 pl-3" : "",
                         open: image_section?(value)) do
      summary = content_tag(:summary, class: "cursor-pointer select-none") do
        safe_join([
          content_tag(:span, key.humanize, class: "text-xs font-semibold uppercase tracking-wide text-gray-500"),
          content_tag(:span, "See more", class: "details-see-more ml-2 text-xs text-blue-600"),
          content_tag(:span, "Hide", class: "details-hide ml-2 text-xs text-blue-600")
        ])
      end

      body =
        if key.to_s.downcase == "prompts"
          render_prompts(value)
        elsif VERBATIM_KEYS.include?(key.to_s.downcase)
          render_verbatim(value)
        elsif key.to_s.downcase == "searches"
          render_searches(value)
        else
          render_output_value(value, depth: depth + 1, key: key, step_id: step_id)
        end

      safe_join([summary, content_tag(:div, body, class: "mt-1")])
    end
  end

  def render_verbatim(value)
    text = value.is_a?(String) ? value : value.to_json
    content_tag(:pre, text, class: "bg-gray-50 border rounded p-2 text-xs overflow-auto whitespace-pre-wrap")
  end

  # A prompts array is a list of long free-text blocks; render each as its own labelled paragraph
  # so the eye can see where one prompt ends and the next begins.
  def render_prompts(value)
    prompts = value.is_a?(Array) ? value : [value]
    content_tag(:div, class: "space-y-3") do
      safe_join(prompts.each_with_index.map { |prompt, index| render_prompt(index, prompt) })
    end
  end

  def render_prompt(index, prompt)
    content_tag(:div, class: "rounded border border-gray-200 bg-gray-50 p-2") do
      safe_join([
        content_tag(:div, "Prompt #{index + 1}",
                    class: "mb-1 text-[10px] font-semibold uppercase tracking-wide text-gray-400"),
        content_tag(:p, prompt.to_s, class: "whitespace-pre-wrap text-sm text-gray-800")
      ])
    end
  end

  def render_output_array(array, depth:, key:, step_id:)
    return content_tag(:span, "[]", class: "text-gray-400") if array.empty?

    if array.all? { |e| e.is_a?(Hash) }
      render_table(array)
    elsif array.all? { |e| e.is_a?(String) && (url?(e) || local_image_path?(e)) }
      render_link_list(array, key: key)
    else
      content_tag(:ul, class: "list-disc ml-5 space-y-1") do
        safe_join(array.map { |e| content_tag(:li) { render_output_value(e, depth: depth + 1, step_id: step_id) } })
      end
    end
  end

  def render_table(rows)
    keys = rows.flat_map(&:keys).uniq
    content_tag(:div, class: "overflow-auto") do
      content_tag(:table, class: "min-w-full text-xs border border-gray-200") do
        head = content_tag(:thead) do
          content_tag(:tr) do
            safe_join(keys.map { |k| content_tag(:th, k.to_s.humanize, class: "border px-2 py-1 bg-gray-50 text-left font-medium") })
          end
        end
        body = content_tag(:tbody) do
          safe_join(rows.map do |row|
            content_tag(:tr) do
              safe_join(keys.map { |k| content_tag(:td, render_table_cell(row[k]), class: "border px-2 py-1 align-top") })
            end
          end)
        end
        safe_join([head, body])
      end
    end
  end

  def render_table_cell(value)
    case value
    when Hash, Array then content_tag(:code, value.to_json, class: "text-[10px]")
    when String      then (url?(value) || local_image_path?(value)) ? link_or_image(value) : value
    when nil         then "—"
    else value.to_s
    end
  end

  def render_searches(searches)
    content_tag(:div, class: "space-y-3") do
      safe_join(Array(searches).filter_map { |search| render_search(search) if search.is_a?(Hash) })
    end
  end

  def render_search(search)
    results = Array(search["results"]).select { |r| r.is_a?(Hash) && r["url"].present? }
    urls = results.any? ? results.map { |r| r["url"] } : Array(search["result_urls"])
    images = Array(search["image_urls"])

    content_tag(:div, class: "border-l-2 border-gray-200 pl-2") do
      safe_join([
        content_tag(:div, search["query"].to_s, class: "font-mono text-xs text-gray-700"),
        (render_link_list(urls, key: nil) if urls.any?),
        (render_link_list(images, key: "images") if images.any?)
      ].compact)
    end
  end

  def render_output_string(value, key:)
    if image_value?(value) || (url?(value) && image_key?(key))
      previewable_image(image_src(value), css: "max-h-64 rounded border")
    elsif url?(value)
      link_or_image(value)
    else
      content_tag(:p, value, class: "whitespace-pre-wrap")
    end
  end

  def render_link_list(items, key:)
    if key && image_key?(key)
      content_tag(:div, class: "mt-1 flex flex-wrap gap-2") do
        safe_join(items.map { |u| previewable_image(image_src(u), css: "h-24 rounded border object-cover") })
      end
    else
      content_tag(:ul, class: "mt-1 space-y-1") do
        safe_join(items.map { |u| content_tag(:li) { link_or_image(u) } })
      end
    end
  end

  def link_or_image(url)
    return previewable_image(image_src(url), css: "max-h-64 rounded border") if image_value?(url)

    content_tag(:div) do
      link = link_to(url, url, target: "_blank", rel: "noopener noreferrer",
                              class: "text-xs text-blue-600 hover:underline break-all")
      preview = content_tag(:details, class: "mt-1") do
        safe_join([
          content_tag(:summary, "Preview", class: "cursor-pointer text-xs text-gray-500"),
          content_tag(:iframe, nil, src: url, loading: "lazy", referrerpolicy: "no-referrer",
                                     sandbox: "allow-scripts allow-popups",
                                     class: "mt-1 h-64 w-full rounded border")
        ])
      end
      safe_join([link, preview])
    end
  end

  def url?(value)
    value.is_a?(String) && value.match?(%r{\Ahttps?://}i)
  end

  def image_url?(value)
    return false unless url?(value)

    IMAGE_EXTENSIONS.any? { |ext| URI.parse(value).path.to_s.downcase.end_with?(ext) }
  rescue URI::InvalidURIError
    false
  end

  def image_key?(key)
    key && IMAGE_KEYS.include?(key.to_s.downcase)
  end

  # A local image on disk or a remote image URL.
  def image_value?(value)
    image_url?(value) || local_image_path?(value)
  end

  # Local images live under the app (tmp/, knowledge_base/) and aren't publicly served, so route
  # them through MediaController; remote URLs are used unchanged.
  def image_src(value)
    url?(value) ? value : media_path(root_relative(value))
  end

  def local_image_path?(value)
    return false unless value.is_a?(String) && value.include?("/")
    return false if url?(value)

    IMAGE_EXTENSIONS.any? { |ext| value.downcase.end_with?(ext) }
  end

  def root_relative(path)
    absolute = File.expand_path(path.to_s, Rails.root.to_s)
    Pathname.new(absolute).relative_path_from(Rails.root).to_s
  rescue ArgumentError
    path.to_s
  end

  # Mark images so the lightbox controller can open them, and give them a zoom cursor.
  def previewable_image(src, css:)
    image_tag(src, class: "#{css} cursor-zoom-in", loading: "lazy", data: { lightbox_image: true })
  end

  def image_section?(value)
    case value
    when Array  then value.any? && value.all? { |e| e.is_a?(String) && image_value?(e) }
    when String then image_value?(value)
    else false
    end
  end
end
