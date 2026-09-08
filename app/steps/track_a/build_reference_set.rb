module Steps
  module TrackA
    class BuildReferenceSet < Steps::Base
      step id: "A1",
           mechanism: :llm_text,
           ownership: "[AGENT-ASSISTED — human curates]"

      MIN_CLOSEUP_FRACTION = 1.0 / 3

      def perform
        criteria = rules("reference_set_criteria")
        text     = prompt("a1_reference_set", style_name: context.fetch(:style_name))

        search_result = Search::ReasonedRunner.call(
          model: Pipeline::TEXT_MODEL,
          schema: Schemas::TrackA::ReferenceSetSchema,
          task: "You are assembling a curated reference-image set for a wall-art style, following " \
                "the search process and per-image requirements given below exactly. Every search " \
                "call must set include_images: true — this task is unusable without real image " \
                "URLs, and a text-only search call will not produce any.",
          question: text,
          max_rounds: 8,  # 1 retailer-guide search + 3 distinct Pinterest queries + 1-2 blog
          # searches, per the source's own 4-step process
          min_rounds: 5   # search floor — the 3 Pinterest queries are required, not a suggestion
        )
        result = search_result[:content]
        issues = validate_set(result)

        needs_human(
          "Curate the reference set (#{search_result[:search_calls_made]} live searches performed). " \
          "#{issues.any? ? "Automated checks flagged: #{issues.join('; ')}" : 'Automated checks passed.'}",
          { candidates: result, issues: issues, criteria: criteria.rules["image_requirements"],
            search_calls_made: search_result[:search_calls_made],
            min_rounds_met: search_result[:min_rounds_met],
            prompt: text, searches: search_result[:searches] }
        )
      rescue Search::NoSearchPerformedError => e
        fail_step("A1 could not complete: #{e.message}", { text: text })
      end

      private

      # Mechanical checks only. The curation judgment stays with the human.
      def validate_set(result)
        issues = []
        images = Array(result["images"]).select { |i| i.is_a?(Hash) }

        if images.empty?
          issues << "no candidate images returned"
          return issues
        end

        closeups = images.count { |i| i["shot_type"] == "closeup" }
        if closeups.to_f / images.size < MIN_CLOSEUP_FRACTION
          issues << "only #{closeups}/#{images.size} close-ups (need at least a third)"
        end

        weak = images.select { |i| (i["attributing_sources"] || []).size < 2 }
        issues << "#{weak.size} image(s) attributed by fewer than 2 independent sources" if weak.any?

        by_source = images.group_by { |i| i["source_name"] }
        over = by_source.select { |_, v| v.size > 4 }.keys
        issues << "source cap exceeded (max ~4 each): #{over.join(', ')}" if over.any?

        issues << "in-situ shots missing" if images.none? { |i| i["shot_type"] == "in_situ" }

        issues
      end
    end
  end
end
