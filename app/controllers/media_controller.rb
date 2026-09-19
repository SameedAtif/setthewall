class MediaController < ApplicationController
  IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .svg .avif].freeze
  SERVED_ROOTS = [Rails.root.join("tmp"), Rails.root.join("knowledge_base")].freeze

  # Serves a locally generated image (e.g. a C1 candidate saved under tmp/gemini_images) to the
  # notebook. These files live outside public/, so they need a route. Only image files inside the
  # app's tmp/ or knowledge_base/ trees are served, so a crafted path can't read arbitrary files.
  def show
    full = File.expand_path(params[:path].to_s, Rails.root.to_s)
    return head(:not_found) unless serveable?(full)

    send_file full, disposition: "inline"
  end

  private

  def serveable?(full)
    return false unless File.file?(full)
    return false unless IMAGE_EXTENSIONS.include?(File.extname(full).downcase)

    SERVED_ROOTS.any? { |root| full.start_with?("#{root}#{File::SEPARATOR}") }
  end
end
