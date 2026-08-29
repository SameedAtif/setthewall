class StartTrackJob < ApplicationJob
  queue_as :default

  # track: "track_a" | "track_b"
  def perform(track:, style_slug:, style_name: nil, scene_template_id: nil, scene_image: nil)
    Workflow::TrackRunner.start(
      track: track, style_slug: style_slug, style_name: style_name,
      scene_template_id: scene_template_id, scene_image: scene_image
    )
  end
end
