module KbEvolution
  class Proposer
    def self.call(cycle_id:)
      new(cycle_id: cycle_id).call
    end

    def initialize(cycle_id:)
      @cycle_id = cycle_id
      @export_json_path = Rails.root.join("tmp", "evolution", "#{cycle_id}_data.json")
      raise ProposalGenerationError, "Export not found for cycle #{cycle_id}" unless @export_json_path.exist?
    end

    def call
      report = JSON.parse(@export_json_path.read)
      kb_snapshot = build_kb_snapshot

      result = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                      .with_schema(KbEvolution::ProposalListSchema)
                      .ask(build_prompt(report, kb_snapshot))
                      .content

      persist_proposals(result["proposals"])
    end

    private

    # Snapshot every KB file the reviewer might want to change: rules/*, prompts/*, style_specs/*.
    # Claude sees the full text of each; it needs the current content to propose edits.
    def build_kb_snapshot
      snapshot = {}
      Dir[Pipeline::KB_ROOT.join("**/*.{yml,md}")].each do |path|
        rel = Pathname.new(path).relative_path_from(Rails.root).to_s
        snapshot[rel] = File.read(path)
      end
      snapshot
    end

    def build_prompt(report, kb_snapshot)
      <<~PROMPT
        You are analysing one week of Etsy listing performance and proposing specific,
        evidence-grounded edits to the knowledge base that produced those listings.

        # Ground rules

        1. **Every proposal must cite specific pieces or metrics from the report.** No proposal
           that reads "we should make listings more engaging" — it must be "pieces with
           color_role=color_burst averaged 2.3x more views (N=4) than line_only (N=7), so
           color_role.yml's per-role default for color_burst should shift to X."
        2. **Only edit files inside `knowledge_base/`.** Never propose changes to `app/`,
           `config/`, or anywhere else.
        3. **Do not propose Etsy anti-patterns.** The rules in
           `knowledge_base/rules/etsy_antipatterns.yml` list things Etsy explicitly says do not
           work (renewal-chasing, self-search verification, assuming Etsy Plus / Star Seller
           / Etsy Ads move ranking). Proposals matching those patterns will be auto-rejected —
           don't waste a slot on them.
        4. **Small, testable changes beat sweeping ones.** Change one rule value, one prompt
           line, one axis default at a time. Sweeping rewrites can't be attributed to a
           specific effect next week.
        5. **N=1 is not evidence.** A single piece performing well doesn't justify changing a
           rule. Wait for a pattern across at least 3 pieces before proposing an edit driven
           by outcomes.
        6. **If the data is too sparse or the week too quiet, say so and propose zero edits.**
           Proposing weak changes to look useful is worse than proposing nothing.

        # The performance report

        ```json
        #{JSON.pretty_generate(report)}
        ```

        # Current knowledge base

        ```yaml
        #{kb_snapshot.map { |path, content| "# --- #{path} ---\n#{content}" }.join("\n\n")}
        ```

        Return JSON matching the required schema. Each proposal names a specific file, the exact
        snippet to replace (or "append"), the new snippet, and a rationale that cites the
        specific pieces/metrics from the report that justify it.
      PROMPT
    end

    def persist_proposals(proposals)
      Array(proposals).map do |raw|
        KbProposal.create!(
          cycle_id: @cycle_id,
          target_path: raw["target_path"],
          change_type: raw["change_type"],
          old_snippet: raw["old_snippet"],
          new_snippet: raw["new_snippet"],
          rationale: raw["rationale"],
          evidence: raw["evidence"] || {},
          status: "open",
          opened_at: Time.current
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "Skipped invalid proposal: #{e.message} — raw=#{raw.inspect}"
        nil
      end.compact
    end
  end
end
