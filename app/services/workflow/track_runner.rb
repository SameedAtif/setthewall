module Workflow
  # Orchestrates the per-style (Track A) and per-scene (Track B) runs. These run
  # pre-piece, so instead of PieceRecord + StatusMachine they use a TrackRun,
  # and their human gates carry the running context forward across steps.
  class TrackRunner
    SEQUENCES = {
      "track_a" => %w[A0 A1 A2 A3 A4 A5].freeze,
      "track_b" => %w[B0 B1 B2 B3 B4 B5 B6 B7].freeze
    }.freeze

    # Steps whose gate, once approved, re-runs the SAME step with confirmed: true
    # (the step writes the spec and completes) rather than advancing.
    CONFIRM_STEPS = %w[A5 B7].freeze

    # How a step's output (ok result data, or the approved gate's effective output)
    # threads into the accumulated context for downstream steps. Keys are strings
    # (the context is jsonb).
    THREADING = {
      "A1" => ->(out) { { "reference_images" => reference_images_from(out) } },
      "A2" => ->(out) { { "mood" => out.dig("result", "mood") || out["mood"] } },
      "A3" => ->(out) { { "content_type" => out.dig("result", "content_type") || out["content_type"] } },
      "A4" => ->(out) { { "frame_form" => out.dig("result", "frame_form") || out["frame_form"] } },
      "B1" => ->(out) { { "wall_condition" => out["wall_condition"] } },
      "B2" => ->(out) { { "furniture_weight" => out["furniture_weight"] } },
      "B3" => ->(out) { { "room_type" => out["room_type"] } },
      "B4" => ->(out) { { "room_shape" => out["room_shape"] } },
      "B5" => ->(out) { { "space_math" => out["space_math"] } },
      "B6" => ->(out) { { "color_role" => out["color_role"] } }
    }.freeze

    AXIS_KEYS = %w[wall_condition furniture_weight room_type room_shape space_math color_role].freeze

    def self.start(track:, style_slug:, style_name: nil, scene_template_id: nil, scene_image: nil)
      raise ArgumentError, "unknown track #{track.inspect}" unless SEQUENCES.key?(track)

      run = TrackRun.create!(track: track, style_slug: style_slug,
                             scene_template_id: scene_template_id, status: "running")
      run.update!(context: base_context(track, style_slug, style_name, scene_template_id, scene_image))
      advance(run)
      run
    end

    # Resume a track after its open gate is closed by a reviewer.
    def self.resume(gate)
      run = gate.track_run
      raise ArgumentError, "gate ##{gate.id} is not a track gate" unless run

      if CONFIRM_STEPS.include?(gate.step_id)
        context = step_context(run, gate.step_id).merge(confirmed: true)
        run.update!(current_step: gate.step_id, status: "running")
        StepDispatcher.call(step_id: gate.step_id, piece: nil, context: context)
        run.update!(status: "complete")
      else
        run.context = run.context.deep_merge(thread(gate.step_id, gate.effective_output).compact)
        nxt = next_step(run.track, gate.step_id)
        if nxt
          run.update!(current_step: nxt, context: run.context)
          advance(run)
        else
          run.update!(status: "complete", context: run.context)
        end
      end
      run
    end

    def self.next_step(track, step_id)
      seq = SEQUENCES.fetch(track)
      seq[seq.index(step_id) + 1]
    end

    def self.advance(run)
      return if run.complete? || run.failed?

      step_id = run.current_step || SEQUENCES.fetch(run.track).first
      run.update!(current_step: step_id, status: "running")

      context = step_context(run, step_id)
      result = StepDispatcher.call(step_id: step_id, piece: nil, context: context)

      case result.status
      when :ok
        output = (result.data || {}).deep_stringify_keys
        run.context = run.context.deep_merge(thread(step_id, output).compact)
        nxt = SEQUENCES.fetch(run.track)[SEQUENCES.fetch(run.track).index(step_id) + 1]
        if nxt
          run.update!(current_step: nxt)
          advance(run)
        else
          run.update!(status: "complete")
        end
      when :awaiting_human
        HumanGate.create!(
          track_run: run, step_id: step_id,
          gate_kind: step_id.parameterize.underscore,
          status: "open",
          agent_proposal: result.data.to_json,
          context_snapshot: context.deep_stringify_keys,
          opened_at: Time.current,
          notes: result.message
        )
        run.update!(status: "awaiting_human")
      when :failed
        run.update!(status: "failed", last_error: result.message)
      end
    end

    def self.thread(step_id, output)
      THREADING.fetch(step_id, ->(_) { {} }).call(output || {})
    end

    def self.base_context(track, style_slug, style_name, scene_template_id, scene_image)
      ctx = { "style_slug" => style_slug }
      if track == "track_a"
        ctx["style_name"] = style_name
      else
        ctx.merge!(
          "scene_template_id" => scene_template_id,
          "scene_image" => scene_image,
          "scene_name" => scene_template_id,
          "template_ref" => "scene_templates/#{scene_template_id}.yml"
        )
      end
      ctx.compact
    end

    # B6 needs the style's content_type (from the locked Track A spec) plus the B1/B2
    # values; B7 expects the six axes nested under `axes:`. Assemble accordingly.
    def self.step_context(run, step_id)
      ctx = run.context.deep_symbolize_keys
      case step_id
      when "B6"
        spec = KnowledgeBase::StyleSpec.load(run.style_slug)
        ctx = ctx.merge(content_type: spec.style_level[:content_type])
      when "B7"
        axes = ctx.slice(*AXIS_KEYS.map(&:to_sym))
        ctx = ctx.merge(axes: axes)
      end
      ctx
    end

    def self.reference_images_from(out)
      return out["reference_images"] if out["reference_images"].is_a?(Array)

      Array(out.dig("candidates", "images")).filter_map { |i| i["url"] if i.is_a?(Hash) }
    end
    private_class_method :reference_images_from
  end
end
