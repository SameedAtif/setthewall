module Workflow
  # Shared gate/decision side effects used by both the speculative Conductor and the notebook's
  # CellRunner. Methods read `@run` and the including instance's `piece` so the conductor's
  # existing private-helper signatures are preserved.
  module GateHelpers
    def gated?(step_id)
      Workflow::DecisionRules.gated_step_ids.include?(step_id) || %w[C2 P2_6].include?(step_id)
    end

    def acceptance_note(findings)
      advisories = findings.select(&:advisory?)
      return nil if advisories.empty?

      "Accepted #{advisories.size} advisory finding(s): #{advisories.map(&:claim).join(' | ')}"
    end

    def clear_side_effects!(step_id)
      return unless %w[C2 C2_finalists C2_chosen].include?(step_id)

      piece&.update!(chosen_url: nil)
    end

    def capture_ideation_pick!(result)
      name = result.data&.dig(:recommended_focus) || result.data&.dig("recommended_focus")
      return if name.blank?

      @run.update!(dossier_data: @run.dossier_data.merge("style_name" => name))
    end

    def capture_reference_images!(result)
      candidates = result.data&.dig(:candidates) || result.data&.dig("candidates")
      images = candidates&.dig(:images) || candidates&.dig("images")
      urls = Array(images).filter_map { |i| i["url"] if i.is_a?(Hash) }
      return if urls.empty?

      @run.update!(dossier_data: @run.dossier_data.merge("A1" => { "curated_images" => urls }))
    end

    def record_escalation!(step_id, reason, divergence = nil)
      @run.update!(escalations: Array(@run.escalations) + [{
        "step_id" => step_id, "reason" => reason, "divergence" => divergence,
        "at" => Time.current.iso8601
      }.compact])
      true
    end
  end
end
