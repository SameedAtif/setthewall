module Workflow
  # Single source of truth for the notebook's step order: the canonical full run plus the
  # conditional branches (P2_1 → P2_2a–e, conditional P2_3) and the locked-spec shortcuts. The
  # Conductor keeps its own constants for its unattended order; this service drives CellRunner.
  class RunSequencer
    STYLE_ORDER = %w[A_IDEATE A0 A1 A1b A2 A3 A4 A5 A6 A7 B0 B1 B2 B3 B4 B5 B6 B7].freeze
    SCENE_STEPS = %w[B0 B1 B2 B3 B4 B5 B6 B7].freeze
    PIECE_ORDER = %w[C1 C2 P2_0 P2_1 P2_3 P2_4 P2_4b P2_5 P2_6
                     P3_1 P3_1b P3_2 P3_3 P3_4 P3_5 P3_6 P3_7 P3_8].freeze
    FULL_ORDER  = (STYLE_ORDER + PIECE_ORDER).freeze

    # The canonical order for a run's scope. The "locked spec" shortcut is NOT applied here: once a
    # run is in flight, A5/B7 writing the spec must not make the remaining style steps disappear.
    # A new run for an already-locked spec marks those steps `skipped` at preparation time instead.
    def self.order_for(run)
      case run.scope.to_s
      when "style" then STYLE_ORDER.dup
      when "piece" then PIECE_ORDER.dup
      else FULL_ORDER.dup
      end
    end

    # The order to actually walk for this run, with the placement branch inserted after P2_1 and
    # the conditional P2_3 dropped for single-piece sets.
    def self.effective_order(run)
      order = order_for(run)
      piece = run.piece_record
      return order unless piece && order.include?("P2_1")

      branch = branch_step_id(piece)
      if branch
        index = order.index("P2_1")
        order.insert(index + 1, branch) unless order.include?(branch)
      end
      order.delete("P2_3") if piece.piece_count.to_i <= 1
      order
    end

    # First step in the effective order that hasn't completed yet. Stale/awaiting/failed cells are
    # returned (they need to be run or re-run), but a cell that is currently RUNNING or awaiting a
    # human decision BLOCKS forward progress — nothing after it may be materialized yet.
    RUNNABLE_STATUSES = %w[pending queued stale failed].freeze

    def self.next_runnable(run)
      cells = RunStep.where(pipeline_run_record_id: run.id).index_by(&:step_id)
      effective_order(run).each do |step_id|
        cell = cells[step_id]
        return nil if cell && %w[running awaiting_human].include?(cell.status)

        return step_id if cell.nil? || RUNNABLE_STATUSES.include?(cell.status)
      end
      nil
    end

    def self.locked_style?(run)
      KnowledgeBase::StyleSpec.load(run.style_slug)
      true
    rescue StandardError
      false
    end

    def self.locked_scene?(run)
      spec = KnowledgeBase::StyleSpec.load(run.style_slug)
      spec.scene(run.scene_spec_id)
      true
    rescue StandardError
      false
    end

    def self.branch_step_id(piece)
      return nil if piece.placement_branch.blank?

      Phase2::BranchRouter.klass_for(piece.placement_branch).step_id
    rescue ArgumentError
      nil
    end
    private_class_method :branch_step_id
  end
end
