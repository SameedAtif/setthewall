module Agents
  # Module 09 §7 — walks the pipeline unattended in speculative mode, routing each result through
  # the QA specialists, escalating Tier 3 gates, and assembling one reviewable dossier. Contains no
  # judgment of its own: QA agents advise, module 08's DecisionRules decides.
  class Conductor
    ORDER = %w[
      A_IDEATE A0 A1 A2 A3 A4 A5
      B0 B1 B2 B3 B4 B5 B6 B7
      C1 C2 P2_0 P2_1 P2_3 P2_4 P2_4b P2_5 P2_6
      P3_1 P3_1b P3_2 P3_3 P3_4 P3_5 P3_6 P3_7 P3_8
    ].freeze

    def self.run_speculative(style_slug:, scene_spec_id:)
      kb_version = Workflow::PreflightCheck.call!(allow_dirty: true).kb_version

      run = PipelineRunRecord.create!(
        run_id: "run_#{Date.current.strftime('%Y%m%d')}_#{SecureRandom.hex(2)}",
        mode: "speculative", status: "running",
        style_slug: style_slug, scene_spec_id: scene_spec_id,
        kb_version: kb_version,
        piece_record: build_piece(style_slug: style_slug, scene_spec_id: scene_spec_id,
                                  kb_version: kb_version),
        started_at: Time.current
      )
      Workflow::RunMode.with("speculative", run_id: run.run_id) { new(run).call }
      run
    end

    # Seed a PieceRecord for the piece-pipeline half (Track C → Phase 3) from the committed
    # style/scene spec, denormalising the axis values C1 onward read. Returns nil when the spec
    # isn't locked yet — a fresh style's Track A/B will lock it in a committed pass first.
    def self.build_piece(style_slug:, scene_spec_id:, kb_version:)
      spec  = KnowledgeBase::StyleSpec.load(style_slug)
      scene = spec.scene(scene_spec_id)

      piece = PieceRecord.create!(style_spec_slug: style_slug, scene_spec_id: scene_spec_id,
                                  kb_version: kb_version, status: "pending")
      piece.apply_spec!(spec, scene)
      piece.save!
      piece
    rescue KnowledgeBase::IncompleteSpecError
      nil
    end

    def initialize(run) = @run = run

    def call
      Agents::Registry.validate_coverage!

      ORDER.each do |step_id|
        execute(step_id)
      end

      Agents::EvidenceQa.call(run: @run)
      @run.update!(
        dossier_markdown: Dossier::Builder.call(run: @run),
        status: "awaiting_dossier_review",
        dossier_ready_at: Time.current
      )
      @run
    end

    private

    def piece = @run.piece_record

    def execute(step_id)
      context = Context::Assembler.for(step_id, @run)
      result  = Workflow::StepDispatcher.call(step_id: step_id, piece: piece, context: context)
      record_step!(step_id, result)

      tier = Workflow::DecisionRules.tier_for(step_id)
      return if tier == 3 && escalate!(step_id, "tier_3_gate")
      return unless gated?(step_id)

      findings = Agents::Registry.for(step_id).flat_map do |klass|
        klass.call(run: @run, step_id: step_id, result: result, context: context, role: "proposer")
      end

      if tier == 2
        verification = Agents::BlindVerifier.call(run: @run, step_id: step_id, result: result,
                                                  context: context, proposer_findings: findings)
        return escalate!(step_id, "verifier_divergence", verification.divergence) unless verification.agreed
      end

      close_gate(step_id, result, findings)
    end

    def close_gate(step_id, result, findings)
      verdict = Workflow::DecisionRules.verdict_for(step_id: step_id, result: result, findings: findings)
      legal   = Workflow::DecisionRules.legal_dispositions(step_id: step_id, verdict: verdict)

      # A blocking finding always rewinds (the "blocked" verdict permits rewind); otherwise approve.
      disposition = findings.any?(&:blocking?) ? "rewind" : "approve"
      unless legal.include?(disposition)
        escalate!(step_id, "no_legal_agent_disposition", { verdict: verdict })
        return
      end

      Workflow::DecisionRules.validate_disposition!(
        step_id: step_id, verdict: verdict, disposition: disposition, reviewer_kind: "agent",
        payload: { citations: findings.flat_map(&:citations), acceptance_note: acceptance_note(findings) }
      )
      Workflow::GateCloser.call(run: @run, step_id: step_id, verdict: verdict,
                                disposition: disposition, reviewer_kind: "agent", findings: findings)
      record_disposition!(step_id, verdict, disposition)
    end

    def acceptance_note(findings)
      advisories = findings.select(&:advisory?)
      return nil if advisories.empty?

      "Accepted #{advisories.size} advisory finding(s): #{advisories.map(&:claim).join(' | ')}"
    end

    def gated?(step_id)
      Workflow::DecisionRules.gated_step_ids.include?(step_id) || step_id == "C2"
    end

    def record_step!(step_id, result)
      append_step_result("step_id" => step_id, "status" => result.status.to_s,
                         "data" => (result.data || {}).stringify_keys)
    end

    def record_disposition!(step_id, verdict, disposition)
      entry = @run.step_results.find { |r| r["step_id"] == step_id }
      entry["verdict"] = verdict
      entry["disposition"] = disposition
      @run.update!(step_results: @run.step_results)
    end

    def append_step_result(entry)
      @run.update!(step_results: Array(@run.step_results) + [entry])
    end

    def escalate!(step_id, reason, divergence = nil)
      @run.update!(escalations: Array(@run.escalations) + [{
        "step_id" => step_id, "reason" => reason, "divergence" => divergence,
        "at" => Time.current.iso8601
      }.compact])
      true
    end
  end
end
