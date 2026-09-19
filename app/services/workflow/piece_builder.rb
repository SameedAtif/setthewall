module Workflow
  # Seeds a PieceRecord from a committed style/scene spec, denormalising the axis values that the
  # piece pipeline reads. Returns nil when the spec isn't locked yet.
  class PieceBuilder
    def self.build(style_slug:, scene_spec_id:, kb_version:)
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

    # Build (once) and attach a piece to the run. Returns the run's existing piece when present.
    def self.for_run(run)
      return run.piece_record if run.piece_record

      piece = build(style_slug: run.style_slug, scene_spec_id: run.scene_spec_id,
                    kb_version: run.kb_version)
      run.update!(piece_record: piece) if piece
      piece
    end
  end
end
