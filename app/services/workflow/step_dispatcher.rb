module Workflow
  class StepDispatcher
    def self.call(step_id:, piece:, context: {})
      new(step_id: step_id, piece: piece, context: context).call
    end

    def initialize(step_id:, piece:, context:)
      @step_id = step_id
      @piece   = piece
      @context = context
      @registry_entry = registry_lookup!
    end

    def call
      klass = @registry_entry["klass"].constantize
      mark_running!

      result = klass.call(piece: @piece, context: @context)

      case result.status
      when :ok
        StatusMachine.transition!(@piece, to: next_status_after_ok, current_step: @step_id)
        result
      when :awaiting_human
        open_gate!(result)
        StatusMachine.transition!(@piece, to: "awaiting_human", current_step: @step_id)
        result
      when :failed
        StatusMachine.transition!(@piece, to: "failed", current_step: @step_id,
                                  last_error: result.message)
        result
      end
    rescue StandardError => e
      # Catches domain-specific exceptions from any module (search, etsy, compositor, KB loaders)
      # and turns them into a fail_step so the pipeline pauses rather than tearing down.
      StatusMachine.transition!(@piece, to: "failed", current_step: @step_id,
                                last_error: "#{e.class}: #{e.message}")
      raise
    end

    private

    def registry_lookup!
      entry = REGISTRY.find { |e| e["id"] == @step_id }
      raise ArgumentError, "Unknown step_id=#{@step_id.inspect}" unless entry
      entry
    end

    def mark_running!
      # If the piece was awaiting_human on this same step, closing that gate happens elsewhere
      # (the controller updates it before enqueuing the resume job). Here we only set status.
      return if @piece.nil?
      StatusMachine.transition!(@piece, to: "running", current_step: @step_id)
    end

    def open_gate!(result)
      return if @piece.nil?   # Track A/B run pre-piece; gates are recorded differently there
      HumanGate.create!(
        piece_record: @piece,
        step_id: @step_id,
        gate_kind: @registry_entry["title"].parameterize.underscore,
        status: "open",
        agent_proposal: result.data.to_json,
        context_snapshot: @context.deep_stringify_keys,
        opened_at: Time.current,
        notes: result.message
      )
    end

    def next_status_after_ok
      # An ok result at the end of the pipeline (P3_8 published_at) transitions to complete.
      # Otherwise: pending (waiting for the next step to be enqueued).
      last_step_of_pipeline?(@step_id) ? "complete" : "pending"
    end

    def last_step_of_pipeline?(step_id) = step_id == "P3_8"

    REGISTRY = begin
      raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
      # Flatten all phases into one lookup — track_a / track_b / track_c for phase_1,
      # steps for phase_2 and phase_3_module_1.
      [
        *(raw.dig("phase_1", "track_a", "steps") || []),
        *(raw.dig("phase_1", "track_b", "steps") || []),
        *(raw.dig("phase_1", "track_c", "steps") || []),
        *(raw.dig("phase_2", "steps") || []),
        *(raw.dig("phase_3_module_1", "steps") || [])
      ].freeze
    end
  end
end
