class CommitRunJob < ApplicationJob
  queue_as :default

  # The only place a run is replayed in committed mode. Module 09 §9: moving staging files into
  # knowledge_base/, the git commit, and the Etsy publish all happen here — never in a speculative
  # run. Scope decides what replays: style/full commits the locked spec; piece/full publishes.
  def perform(run_id:)
    run = PipelineRunRecord.find_by!(run_id: run_id)
    Workflow::RunMode.with("committed", run_id: run_id) do
      replay_staged_spec(run) if %w[style full].include?(run.scope)
      commit_kb(run) if %w[style full].include?(run.scope)
      apply_reviewer_decisions(run) if %w[piece full].include?(run.scope)
      publish_piece(run) if %w[piece full].include?(run.scope)
      run.update!(mode: "committed", status: "committed")
    end
  end

  private

  def staging_dir(run) = Rails.root.join("tmp", "runs", run.run_id, "staging")

  def replay_staged_spec(run)
    staging = staging_dir(run).join("style_specs")
    return unless staging.directory?

    target = Pipeline::KB_ROOT.join("style_specs")
    target.mkpath
    staging.children.each { |f| FileUtils.cp(f, target.join(f.basename)) }
  end

  def commit_kb(run)
    status = `git status --porcelain knowledge_base/`.strip
    return if status.empty?

    `git add knowledge_base/`
    `git commit -m "Lock style spec for #{run.style_slug} (run #{run.run_id})"`
  end

  def publish_piece(run)
    piece = run.piece_record
    return if piece.nil? || piece.etsy_listing_id.present?

    result = Workflow::StepDispatcher.call(step_id: "P3_8", piece: piece, context: {})
    note = "P3_8 on commit: #{result.status}".strip
    run.update!(reviewer_notes: [run.reviewer_notes, note].compact.join(" ").strip)
  rescue StandardError => e
    note = "publish skipped: #{e.message}"
    run.update!(reviewer_notes: [run.reviewer_notes, note].compact.join(" ").strip)
  end

  def apply_reviewer_decisions(run)
    piece = run.piece_record
    return unless piece

    decisions = run.reviewer_decisions || {}

    chosen = decisions.dig("C2", "chosen_url")
    if chosen.present? && Array(piece.finalist_urls).include?(chosen)
      piece.update!(chosen_url: chosen)
    end

    pricing = decisions["P3_7"]
    return if pricing.blank? || piece.listing_attributes.present?

    required = %w[return_policy shipping_price_usd item_price_usd]
    return unless required.all? { |k| pricing[k].present? }

    Steps::Phase3::ShippingAndReturns.call(
      piece: piece,
      context: { confirmed: true, return_policy: pricing["return_policy"],
                 shipping_price_usd: pricing["shipping_price_usd"].to_f,
                 item_price_usd: pricing["item_price_usd"].to_f }
    )
  end
end
