module Agents
  # A_IDEATE, A0, A1 — the research steps. Binds to the search accounting (min_rounds_met /
  # search_calls_made), source independence, promotional framing, and the A0 breadth / A1
  # mood-cluster signals that catch a fragmented style before it costs a full scoring pass.
  class ResearchQa < Base
    agent id: "research_qa", covers: %w[A_IDEATE A0 A1]

    def evaluate
      d = data
      findings = []

      findings.concat(search_floor(d))
      findings.concat(check_source_independence(d))
      findings.concat(check_promotional_framing(d))

      if @step_id == "A0" && d.dig("findings", "breadth_assessment") == "fragments_into_substyles"
        findings << blocking(
          "Style fragments into distinct sub-themes. This is not one coherent style, and the " \
          "agent's single_recommended_focus is a narrowing proposal, not an answer.",
          [cite("decision_rules.rules.steps.A0.on_unresolved_input")],
          { recommended_focus: d.dig("findings", "single_recommended_focus") }
        )
      end

      if @step_id == "A1"
        clusters = Array(d.dig("candidates", "mood_clusters_found"))
        if clusters.size > 1
          findings << blocking(
            "Reference set spans #{clusters.size} mood clusters. Narrowing now is cheaper than " \
            "discovering the same split after A2's full scoring pass.",
            [cite("decision_rules.rules.steps.A1.on_unresolved_input")],
            { clusters: clusters.filter_map { |c| c["label"] } }
          )
        end
      end

      return [pass("Research output is clean — sources independent.",
                   [cite("qa_rules.rules.research_qa.source_independence")])] if findings.empty?

      findings
    end

    private

    def search_floor(d)
      return [] unless d.key?("min_rounds_met")

      calls = d["search_calls_made"].to_i
      if d["min_rounds_met"]
        [pass("Search methodology floor met (#{calls} live calls).",
              [cite("qa_rules.rules.research_qa.search_floor")])]
      else
        [blocking("Search stopped short of the declared minimum (#{calls} calls). " \
                  "Findings are thinner than the methodology requires.",
                  [cite("qa_rules.rules.research_qa.search_floor")], { search_calls_made: calls })]
      end
    end

    def check_source_independence(d)
      images = Array(d.dig("candidates", "images") || d["images"])
      return [] if images.empty?

      min = qa_rules.dig("source_independence", "min_sources_per_item").to_i
      weak = images.select { |i| Array(i["attributing_sources"]).size < min }
      return [pass("Every item carries #{min}+ independent attributing sources.",
                   [cite("reference_set_criteria.rules.image_requirements")])] if weak.empty?

      [advisory("#{weak.size} item(s) attributed by fewer than #{min} independent sources.",
                [cite("reference_set_criteria.rules.image_requirements")], { weak_count: weak.size })]
    end

    def check_promotional_framing(d)
      phrases = Array(rules("ideation_constraints").rules
                        .dig("promotional_language_indicators", "phrases"))
      blob = d.to_s.downcase
      hits = phrases.select { |p| blob.include?(p.downcase) }
      return [] if hits.empty?

      [advisory("Source language matches promotional-framing patterns (#{hits.join(', ')}). " \
                "Treat the trend claim as one source's marketing, not neutral evidence.",
                [cite("ideation_constraints.rules.promotional_language_indicators")], { matched: hits })]
    end
  end
end
