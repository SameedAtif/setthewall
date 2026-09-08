module Steps
  module TrackC
    class CullToFinalists < Steps::Base
      step id: "C2",
           mechanism: :human,
           ownership: "[AGENT-ASSISTED — human makes final pick]"

      # context: { finalist_urls: [..], chosen_url: '...' }
      #
      # Two-stage: the human first narrows to finalists (returned as needs_human once), then
      # picks one chosen from those (returned as needs_human again). On the third call, with
      # chosen_url set, the step completes.
      def perform
        candidates = piece.candidate_urls
        return fail_step("no candidates on piece — C1 hasn't produced any", {}) if candidates.empty?

        rules_data = rules("generation_constraints").rules

        finalists_requested = Array(context[:finalist_urls])
        chosen              = context[:chosen_url]

        # === Stage 1: propose finalists ===
        if finalists_requested.empty?
          return needs_human(
            "Cull the batch of #{candidates.size} to at most #{rules_data['finalist_cull']['max_finalists_per_scene']} " \
            "finalists (absolute max #{rules_data['finalist_cull']['absolute_max']}). Set " \
            "finalist_urls on the piece.",
            { candidates: candidates,
              cull_target: rules_data["finalist_cull"]["max_finalists_per_scene"],
              cull_absolute_max: rules_data["finalist_cull"]["absolute_max"] }
          )
        end

        # Validation: finalists must be a subset of candidates, and within cull limits
        invalid = finalists_requested - candidates
        if invalid.any?
          return fail_step("finalist_urls contains URLs not in candidate_urls: #{invalid.take(3).inspect}", {})
        end

        absolute_max = rules_data["finalist_cull"]["absolute_max"]
        if finalists_requested.size > absolute_max
          return fail_step(
            "Cull produced #{finalists_requested.size} finalists; absolute maximum is #{absolute_max}. " \
            "The cull discipline is the point of this step — narrow further.",
            { finalists_count: finalists_requested.size, absolute_max: absolute_max }
          )
        end

        piece.update!(finalist_urls: finalists_requested)

        # === Stage 2: pick one chosen ===
        if chosen.blank?
          return needs_human(
            "Pick ONE finalist as the day's chosen piece. This becomes PieceRecord.chosen_url " \
            "and flows into Phase 2 — no more finalists carry forward.",
            { finalists: finalists_requested }
          )
        end

        unless finalists_requested.include?(chosen)
          return fail_step("chosen_url is not in finalist_urls", { chosen: chosen, finalists: finalists_requested })
        end

        index = piece.candidate_urls.index(chosen)
        piece.update!(
          chosen_url: chosen,
          chosen_subject: index && piece.candidate_subjects[index],
          chosen_pattern: index && piece.candidate_patterns[index]
        )
        ok({ finalist_urls: finalists_requested, chosen_url: chosen })
      end
    end
  end
end
