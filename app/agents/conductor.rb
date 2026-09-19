module Agents
  # Module 09 §7 — walks the pipeline unattended in speculative mode, routing each result through
  # the QA specialists, escalating Tier 3 gates, and assembling one reviewable dossier. Contains no
  # judgment of its own: QA agents advise, module 08's DecisionRules decides.
  #
  # Three scopes share this class:
  #   style  — Track A + Track B (A0 → B7), locks the style/scene spec, no piece.
  #   piece  — Track C → Phase 3 (C1 → P3_8) against an already-locked spec.
  #   full   — style + piece in one pass, one dossier.
  #
  # The per-step execution (dispatch + QA + gate closure) lives in Workflow::StepExecution, shared
  # with the notebook's Workflow::CellRunner.
  class Conductor
    include Workflow::GateHelpers

    ORDER = %w[
      C1 C2 P2_0 P2_1 P2_3 P2_4 P2_4b P2_5 P2_6
      P3_1 P3_1b P3_2 P3_3 P3_4 P3_5 P3_6 P3_7 P3_8
    ].freeze

    STYLE_ORDER = %w[A_IDEATE A0 A1 A2 A3 A4 A5 A6 A7 B0 B1 B2 B3 B4 B5 B6 B7].freeze
    FULL_ORDER  = (STYLE_ORDER + ORDER).freeze

    SCOPES = {
      "style" => STYLE_ORDER,
      "piece" => ORDER,
      "full"  => FULL_ORDER
    }.freeze

    def self.order_for(scope) = SCOPES.fetch(scope.to_s, ORDER)

    def self.run_speculative(style_slug:, scene_spec_id:, scope: "piece",
                             style_name: nil, scene_image: nil)
      kb_version = Workflow::PreflightCheck.call!(allow_dirty: true).kb_version
      run_context = { "style_name" => style_name, "scene_image" => scene_image }.compact

      piece = scope.to_s == "piece" ? build_piece(style_slug: style_slug,
                                                  scene_spec_id: scene_spec_id,
                                                  kb_version: kb_version) : nil

      run = PipelineRunRecord.create!(
        run_id: "run_#{Date.current.strftime('%Y%m%d')}_#{SecureRandom.hex(2)}",
        mode: "speculative", status: "running", scope: scope.to_s,
        style_slug: style_slug, scene_spec_id: scene_spec_id,
        kb_version: kb_version, dossier_data: run_context,
        piece_record: piece,
        started_at: Time.current
      )
      Workflow::RunMode.with("speculative", run_id: run.run_id) { new(run).call }
      run
    end

    # Seed a PieceRecord for the piece pipeline from the committed style/scene spec. Returns nil
    # when the spec isn't locked yet — a fresh style's Track A/B locks it first (committed, or in
    # the staged spec of a full run).
    def self.build_piece(style_slug:, scene_spec_id:, kb_version:)
      Workflow::PieceBuilder.build(style_slug: style_slug, scene_spec_id: scene_spec_id,
                                   kb_version: kb_version)
    end

    def initialize(run) = @run = run

    def call
      Agents::Registry.validate_coverage!

      self.class.order_for(@run.scope).each do |step_id|
        execute(step_id)
      end

      Agents::EvidenceQa.call(run: @run)
      @run.update!(status: "awaiting_dossier_review", dossier_ready_at: Time.current)
      @run.update!(dossier_markdown: Dossier::Builder.call(run: @run))

      dir = Rails.root.join("tmp", "runs", @run.run_id)
      dir.mkpath
      dir.join("dossier.md").write(@run.dossier_markdown)
      @run
    end

    private

    def piece = @run.piece_record

    def execute(step_id)
      outcome = Workflow::StepExecution.call(run: @run, step_id: step_id, piece: piece)
      record_step!(step_id, outcome.result)
      record_disposition!(step_id, outcome.verdict, outcome.disposition) if outcome.disposition.present?
    rescue StandardError => e
      # Safety net: StepExecution already converts step errors into a failed result, but recording
      # itself must never tear down the whole run.
      failed = Workflow::StepExecution::FailureResult.new(
        status: :failed, data: { "error" => e.message }, message: nil
      )
      record_step!(step_id, failed)
      record_escalation!(step_id, "step_error", e.message)
    end

    def record_step!(step_id, result)
      entry = { "step_id" => step_id, "status" => result.status.to_s,
                "data" => (result.data || {}).stringify_keys }
      entry["message"] = result.message if result.respond_to?(:message) && result.message.present?
      append_step_result(entry)
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
  end
end
