module Context
  # Builds a step's context from the run's base values plus prior step results. This is the
  # cross-step carry-forward for the conductor (the piece-pipeline equivalent of module 01c's
  # TrackASequence::SOURCES), now extended across Track A, Track B, and the piece pipeline.
  #
  # Taint rule: a step whose recorded disposition is `rewind`/`abandon`, or whose status is
  # `failed`, must not contribute values downstream. A blocked step's output is treated as
  # absent, so the next step either fails cleanly or (for the A5/B7 locks) cannot satisfy its
  # required axes and escalates instead of locking a rejected value.
  class Assembler
    def self.for(step_id, run)
      new(step_id, run).build
    end

    def initialize(step_id, run)
      @step_id = step_id
      @run = run
      @entries = entries_by_step
      @results = @entries.transform_values { |e| (e["data"] || {}).stringify_keys }
    end

    def build
      base.merge(derived).merge(provisional).merge(step_override)
    end

    private

    # A per-step context override set when the reviewer re-runs a step with a new scope (e.g. A1
    # narrowed to a single mood cluster). Merged last so it wins.
    def step_override
      entry = RunStep.find_by(pipeline_run_record_id: @run.id, step_id: @step_id)
      (entry&.context_override || {}).deep_symbolize_keys
    end

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

    def entries_by_step
      Array(@run.step_results).each_with_object({}) do |r, acc|
        acc[r["step_id"]] = r if r["step_id"]
      end
    end

    def tainted?(step_id)
      entry = @entries[step_id]
      return false unless entry
      return true if %w[failed stale].include?(entry["status"])

      %w[stale rewind abandon].include?(entry["disposition"])
    end

    def dig(*keys) = @results.dig(*keys)

    def result_of(step)
      (dig(step, "result") || dig(step) || {}).stringify_keys
    end

    def reference_images
      return [] if tainted?("A1")

      images = dig("A1", "candidates", "images")
      Array(images).filter_map { |i| i["url"] if i.is_a?(Hash) }
    end

    # A curated mix for C1: close-up/product shots carry the surface and medium, while in-situ
    # shots carry palette and styling. Outliers are dropped when A1 flags them. Falls back to
    # whatever is available.
    def style_reference_images
      return [] if tainted?("A1")

      outliers = Array(reference_essence["outlier_indices"]).map(&:to_i)
      images = Array(dig("A1", "candidates", "images")).each_with_index
               .reject { |_image, i| outliers.include?(i + 1) }
               .map(&:first)
               .select { |i| i.is_a?(Hash) && i["url"].present? }
               .reject { |i| i["is_outlier"] }
      closeups = images.select { |i| i["shot_type"].to_s == "closeup" }
      in_situ  = images.reject { |i| i["shot_type"].to_s == "closeup" }
      (closeups.first(3) + in_situ.first(2)).map { |i| i["url"] }.presence ||
        images.map { |i| i["url"] }
    end

    # The typed reference essence distilled by A1b — the style's shared medium/palette/surface/
    # motif facts. No prose fallback: a style without an A1b essence simply has none.
    def reference_essence
      return {} if tainted?("A1b")

      dig("A1b", "essence") || {}
    end

    def style_name_used
      dig("A0", "style_name_used") || @run.dossier_data["style_name"]
    end

    def mood = tainted?("A2") ? nil : result_of("A2")["mood"]
    def content_type = tainted?("A3") ? nil : result_of("A3")["content_type"]
    def frame_form = tainted?("A4") ? nil : result_of("A4")["frame_form"]

    def production_model
      return nil if tainted?("A0")

      dig("A0", "findings", "production_model")
    end

    def scene_axis(step, key)
      tainted?(step) ? nil : dig(step, key)
    end

    def scene_axes
      {
        wall_condition: scene_axis("B1", "wall_condition"),
        furniture_weight: scene_axis("B2", "furniture_weight"),
        room_type: scene_axis("B3", "room_type"),
        room_shape: scene_axis("B4", "room_shape"),
        space_math: scene_axis("B5", "space_math"),
        color_role: scene_axis("B6", "color_role")
      }
    end

    def derived
      case @step_id
      when "A1"          then { style_name: style_name_used }
      when "A2", "A3"    then { reference_images: reference_images }
      when "A4"          then { reference_images: reference_images, mood: mood }
      when "A1b"         then { reference_images: reference_images }
      when "A5"          then { style_name: style_name_used, mood: mood,
                                content_type: content_type, frame_form: frame_form,
                                production_model: production_model,
                                reference_essence: reference_essence }
      when "B6"          then { content_type: content_type,
                                wall_condition: scene_axis("B1", "wall_condition"),
                                furniture_weight: scene_axis("B2", "furniture_weight") }
      when "B7"          then { axes: scene_axes }
      when "C1"          then { reference_images: style_reference_images, reference_essence: reference_essence }
      else {}
      end
    end

    # Tier 3 confirm steps never auto-fill `confirmed` in the committed flow, but a speculative
    # full run must provisionally complete them so downstream steps can run against the staged
    # spec. The provisional confirm only fires when every required axis is clean — a tainted
    # upstream value means the lock must NOT write it, and the step escalates instead.
    def provisional
      case @step_id
      when "A5" then axes_clean? ? { confirmed: true } : {}
      when "B7" then scene_axes.values.all?(&:present?) ? { confirmed: true } : {}
      when "C2" then c2_context
      else {}
      end
    end

    def axes_clean?
      mood.present? && content_type.present? && frame_form.present?
    end

    def c2_context
      candidates = Array(@run.piece_record&.candidate_urls)
      return {} if candidates.empty?

      finalists = candidates.first(3)
      { finalist_urls: finalists, chosen_url: finalists.first }
    end
  end
end
