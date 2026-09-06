module Context
  # Builds a step's context from the run's base values plus prior step results. This is the
  # cross-step carry-forward for the conductor (the piece-pipeline equivalent of module 01c's
  # TrackASequence::SOURCES), now extended across Track A, Track B, and the piece pipeline.
  class Assembler
    def self.for(step_id, run)
      new(step_id, run).build
    end

    def initialize(step_id, run)
      @step_id = step_id
      @run = run
      @results = results_by_step
    end

    def build
      base.merge(derived).merge(provisional)
    end

    private

    def base
      {
        style_slug: @run.style_slug,
        scene_spec_id: @run.scene_spec_id,
        style_name: @run.dossier_data["style_name"],
        scene_image: @run.dossier_data["scene_image"],
        scene_template_id: @run.scene_spec_id,
        scene_name: @run.scene_spec_id,
        template_ref: "scene_templates/#{@run.scene_spec_id}.yml"
      }.compact
    end

    def results_by_step
      Array(@run.step_results).each_with_object({}) do |r, acc|
        acc[r["step_id"]] = (r["data"] || {}).stringify_keys if r["step_id"]
      end
    end

    def dig(*keys) = @results.dig(*keys)

    def result_of(step)
      (dig(step, "result") || dig(step) || {}).stringify_keys
    end

    def reference_images
      images = dig("A1", "candidates", "images")
      Array(images).filter_map { |i| i["url"] if i.is_a?(Hash) }
    end

    def style_name_used
      dig("A0", "style_name_used") || @run.dossier_data["style_name"]
    end

    def mood = result_of("A2")["mood"]
    def content_type = result_of("A3")["content_type"]
    def frame_form = result_of("A4")["frame_form"]

    def scene_axes
      {
        wall_condition: dig("B1", "wall_condition"),
        furniture_weight: dig("B2", "furniture_weight"),
        room_type: dig("B3", "room_type"),
        room_shape: dig("B4", "room_shape"),
        space_math: dig("B5", "space_math"),
        color_role: dig("B6", "color_role")
      }
    end

    def derived
      case @step_id
      when "A1"          then { style_name: style_name_used }
      when "A2", "A3"    then { reference_images: reference_images }
      when "A4"          then { reference_images: reference_images, mood: mood }
      when "A5"          then { style_name: style_name_used, mood: mood,
                                content_type: content_type, frame_form: frame_form }
      when "B6"          then { content_type: content_type,
                                wall_condition: dig("B1", "wall_condition"),
                                furniture_weight: dig("B2", "furniture_weight") }
      when "B7"          then { axes: scene_axes }
      else {}
      end
    end

    # Tier 3 confirm steps never auto-fill `confirmed` in the committed flow, but a speculative
    # full run must provisionally complete them so downstream steps can run against the staged
    # spec. The decision still escalates to the dossier; this only unblocks the dry run.
    def provisional
      case @step_id
      when "A5" then { confirmed: true }
      when "B7" then { confirmed: true }
      when "C2" then c2_context
      else {}
      end
    end

    def c2_context
      candidates = Array(@run.piece_record&.candidate_urls)
      return {} if candidates.empty?

      finalists = candidates.first(3)
      { finalist_urls: finalists, chosen_url: finalists.first }
    end
  end
end
