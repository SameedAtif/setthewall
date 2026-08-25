module Workflow
  class PipelineRun
    DAILY_SEQUENCE = %w[C1 C2 P2_1 branch_2x P2_3 P2_4 P2_4b P2_5 P2_6 P3_1 P3_1b P3_2 P3_3 P3_4 P3_5 P3_6 P3_7 P3_8].freeze

    # Kick off a daily pipeline for one piece.
    # style_slug / scene_spec_id must be a locked spec.
    def self.start_daily(style_slug:, scene_spec_id:)
      spec = KnowledgeBase::StyleSpec.load(style_slug)
      scene = spec.scene(scene_spec_id)

      kb_version = PreflightCheck.call!.kb_version

      piece = PieceRecord.create!(
        style_spec_slug: style_slug,
        scene_spec_id: scene_spec_id,
        kb_version: kb_version,
        status: "pending"
      )
      piece.apply_spec!(spec, scene)
      piece.save!

      ProcessPieceJob.perform_later(piece_id: piece.id, step_id: "C1")
      piece
    end

    # After a step returns ok, figure out what to run next.
    def self.next_step_after(step_id, piece)
      # Step 1 → branch to one of 2a-2e
      return branch_2x_step(piece) if step_id == "P2_1"

      # 2a-2e → 3 (if a set) or 4 (if single)
      if %w[P2_2a P2_2b P2_2c P2_2d P2_2e].include?(step_id)
        return piece.piece_count.to_i > 1 ? "P2_3" : "P2_4"
      end

      # Terminal
      return nil if step_id == "P3_8"

      # Straight line for everything else
      idx = LINEAR.index(step_id)
      return nil if idx.nil?
      LINEAR[idx + 1]
    end

    LINEAR = %w[C1 C2 P2_0 P2_1 P2_3 P2_4 P2_4b P2_5 P2_6 P3_1 P3_1b P3_2 P3_3 P3_4 P3_5 P3_6 P3_7 P3_8].freeze

    def self.branch_2x_step(piece)
      Phase2::BranchRouter.klass_for(piece.placement_branch).step_id
    end
  end
end
