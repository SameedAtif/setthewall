module KbEvolution
  class AntiRegressionScanner
    def self.call(proposal)
      rules = KnowledgeBase::RuleSet.load("anti_regressions").rules
      flags = []

      combined = "#{proposal.rationale} #{proposal.new_snippet}".downcase

      Array(rules["hard_blocks"]).each do |block|
        indicators = Array(block["pattern_indicators"]).map(&:to_s).map(&:downcase)
        if indicators.any? { |ind| combined.include?(ind) }
          flags << { severity: :hard_block, rule: block["name"], description: block["description"] }
        end
      end

      Array(rules["soft_flags"]).each do |flag|
        # Only one soft flag currently has a mechanical trigger: single_piece_generalisation.
        # replace_file is a UI hint, not a data-driven check.
        if flag["name"] == "single_piece_generalisation"
          pids = proposal.evidence.dig("piece_ids") || []
          if pids.size < 3
            flags << { severity: :warning, rule: flag["name"], description: flag["description"] }
          end
        end
        if flag["name"] == "sweeping_replace_file" && proposal.change_type == "replace_file"
          flags << { severity: :warning, rule: flag["name"], description: flag["description"] }
        end
      end

      flags
    end
  end
end
