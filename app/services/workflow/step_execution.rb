module Workflow
  # The shared per-step execution path. Runs the step, records its domain side effects (gates,
  # escalations, A0/A1 captures), and reports the outcome so callers persist it: the Conductor
  # appends to PipelineRunRecord#step_results, while CellRunner writes a RunStep (which mirrors
  # back into step_results). Behavior is intentionally identical to the former
  # Conductor#execute.
  class StepExecution
    include Workflow::GateHelpers

    # A minimal failed result that does not depend on step classes being loaded (tests stub
    # StepDispatcher, so Steps::StepResult may not be available).
    FailureResult = Struct.new(:status, :data, :message, keyword_init: true)

    Outcome = Struct.new(:result, :context, :findings, :verdict, :disposition, :pause,
                         keyword_init: true) do
      def status = result&.status
      def data = result&.data || {}
      def message = result.respond_to?(:message) ? result.message : nil
      def ok? = status == :ok
      def awaiting_human? = status == :awaiting_human
      def failed? = status == :failed
      def paused? = !!pause
      def disposition?(value) = disposition.to_s == value.to_s
    end

    def self.call(run:, step_id:, piece: nil, log: nil)
      new(run: run, step_id: step_id, piece: piece, log: log).call
    end

    def initialize(run:, step_id:, piece: nil, log: nil)
      @run = run
      @step_id = step_id
      @piece = piece
      @log = log
    end

    def call
      @piece = Workflow::PieceBuilder.for_run(@run) if @step_id == "C1" && @piece.nil?

      context = Context::Assembler.for(@step_id, @run)
      log("Dispatching #{@step_id}")
      result  = Workflow::StepDispatcher.call(step_id: @step_id, piece: piece, context: context)
      log("Step returned #{result.status}")
      capture_ideation_pick!(result) if @step_id == "A_IDEATE"
      capture_reference_images!(result) if @step_id == "A1"
      capture_reference_essence!(result) if @step_id == "A1b"

      tier = Workflow::DecisionRules.tier_for(@step_id)
      if tier == 3
        # Human-only: never let an agent close it.
        log("Tier 3 (human-only) — pausing for review", level: :warn)
        record_escalation!(@step_id, "tier_3_gate")
        return outcome(result, context: context, pause: true)
      end

      return outcome(result, context: context, pause: awaiting?(result)) unless gated?(@step_id)

      log("Running QA agents")
      findings = Agents::Registry.for(@step_id).flat_map do |klass|
        klass.call(run: @run, step_id: @step_id, result: result, context: context, role: "proposer")
      end
      log("QA findings: #{findings.size}")

      if tier == 2
        log("Blind verification (tier 2)")
        verification = Agents::BlindVerifier.call(run: @run, step_id: @step_id, result: result,
                                                  context: context, proposer_findings: findings)
        unless verification.agreed
          log("Verifier diverged — escalating", level: :warn)
          record_escalation!(@step_id, "verifier_divergence", verification.divergence)
          return outcome(result, context: context, findings: findings, pause: awaiting?(result))
        end
      end

      verdict = Workflow::DecisionRules.verdict_for(step_id: @step_id, result: result, findings: findings)
      legal   = Workflow::DecisionRules.legal_dispositions(step_id: @step_id, verdict: verdict)
      disposition = findings.any?(&:blocking?) ? "rewind" : "approve"
      unless legal.include?(disposition)
        log("No legal disposition for verdict=#{verdict}", level: :warn)
        record_escalation!(@step_id, "no_legal_agent_disposition", { "verdict" => verdict })
        return outcome(result, context: context, findings: findings, verdict: verdict)
      end

      Workflow::DecisionRules.validate_disposition!(
        step_id: @step_id, verdict: verdict, disposition: disposition, reviewer_kind: "agent",
        payload: { citations: findings.flat_map(&:citations), acceptance_note: acceptance_note(findings) }
      )
      Workflow::GateCloser.call(run: @run, step_id: @step_id, verdict: verdict,
                                disposition: disposition, reviewer_kind: "agent", findings: findings)
      log("Gate: verdict=#{verdict} disposition=#{disposition}")

      if disposition == "rewind"
        claims = findings.select(&:blocking?).map(&:claim).join(" | ")
        record_escalation!(@step_id, "rewind", claims)
        clear_side_effects!(@step_id)
      end

      outcome(result, context: context, findings: findings, verdict: verdict, disposition: disposition)
    rescue StandardError => e
      log("Error: #{e.class}: #{e.message}", level: :error)
      failed = FailureResult.new(status: :failed, data: { "error" => e.message }, message: nil)
      record_escalation!(@step_id, "step_error", e.message)
      outcome(failed, context: {}, pause: false)
    end

    def piece = @piece || @run.piece_record

    private

    def log(message, level: :info) = @log&.call(message, level: level)

    def awaiting?(result) = result.status == :awaiting_human

    def outcome(result, context: {}, findings: [], verdict: nil, disposition: nil, pause: false)
      Outcome.new(result: result, context: context, findings: findings, verdict: verdict,
                  disposition: disposition, pause: pause)
    end
  end
end
