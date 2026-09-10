module Dossier
  # Module 09 §8 — assembles the reviewable report from the run, its escalations, its QA findings,
  # the piece's outputs, the locked style spec, and the A0 research gate. The report is one section
  # per step (A_IDEATE → P3_8), each telling the step's own story: what it found, what it
  # recommended, the prompt it issued, the live searches it ran (with the links they surfaced), and
  # the images it produced. The report never opens with cost or duration (SR4).
  class Builder
    def self.call(run:) = new(run).call

    def initialize(run) = @run = run

    def call
      sections = [header]
      sections << what_we_propose if piece
      sections << open_questions
      sections.concat(step_sections)
      sections.concat([why_it_will_work, cannot_verify, if_you_approve])
      sections.join("\n\n")
    end

    private

    def piece = @run.piece_record

    def header
      "# Run #{@run.run_id} — #{@run.style_slug} / #{@run.scene_spec_id}\n" \
      "Mode: #{@run.mode} · KB version: #{@run.kb_version} · Status: #{@run.status}"
    end

    def what_we_propose
      lines = ["## What we are proposing to publish"]
      lines << "**Title:** #{piece&.listing_title.presence || '—'} "
      lines << "**Category:** #{piece&.listing_category.presence || '—'}"
      lines << "**Tags:** #{Array(piece&.listing_tags).join(', ')}"
      lines << ""
      lines << "**Description:**"
      lines << (piece&.listing_description.presence || "—")
      lines.join("\n")
    end

    def open_questions
      escalations = Array(@run.escalations)
      return "## Open questions\nNone." if escalations.empty?

      "## Open questions\n" + escalations.map { |e| "- #{open_question_line(e)}" }.join("\n")
    end

    def open_question_line(e)
      label = "#{step_title(e['step_id'])} (#{e['step_id']})"
      case e["reason"]
      when "tier_3_gate"
        msg = message_for(e["step_id"])
        "#{label} — needs your decision#{msg.present? ? ": #{truncate(msg, 300)}" : ''}"
      when "step_error"
        "#{label} — failed: #{e['divergence'] || 'unknown error'}"
      when "rewind"
        "#{label} — blocked by a QA check and must be re-run: #{e['divergence']}"
      when "verifier_divergence"
        "#{label} — the QA checks disagreed (proposer: #{e.dig('divergence', 'proposer')}, " \
        "verifier: #{e.dig('divergence', 'verifier')})"
      when "no_legal_agent_disposition"
        "#{label} — no valid automatic decision was possible; needs your call"
      else
        "#{label} — #{e['reason']}"
      end
    end

    # --- Per-step sections -------------------------------------------------

    def step_sections
      Array(@run.step_results).map { |r| step_section(r) }
    end

    def step_section(record)
      lines = ["## #{step_title(record['step_id'])} (#{record['step_id']}) — #{status_word(record['status'])}"]
      lines << ""

      narrative = step_narrative(record)
      lines << narrative if narrative.present?

      prompt = prompt_for(record)
      if prompt.present?
        lines << ""
        lines << "### Prompt issued"
        lines << "```"
        lines << prompt.to_s
        lines << "```"
      end

      searches = searches_for(record)
      if searches.any?
        lines << ""
        lines << "### Live searches (queries the model generated from the prompt above, and the links they surfaced)"
        searches.each { |s| lines.concat(search_lines(s)) }
      end

      images = step_images(record)
      if images.any?
        lines << ""
        lines << "### Images"
        images.each { |u| lines << "![#{File.basename(u.to_s)}](#{relative(u)})" }
      end

      lines.join("\n")
    end

    def status_word(status)
      { "ok" => "completed", "awaiting_human" => "needs your review",
        "failed" => "failed" }.fetch(status.to_s, status.to_s)
    end

    def step_narrative(record)
      parts = []
      message = record["message"].to_s.strip
      parts << message if message.present?

      if record["step_id"] == "A0"
        findings = a0_findings
        parts.concat(findings.map { |f| finding_line(f) }) if findings.present?
      end

      summary = narrative_summary(record)
      parts << summary if summary.present?

      parts.join("\n\n")
    end

    def finding_line(f)
      cross = f["cross_check_confirmed"] ? "confirmed" : "not confirmed"
      "- **#{f['theme']}** — #{f['demand_to_competition_verdict']} " \
      "(shops: #{f['independent_shops']}, competition: #{f['competition_density']}, " \
      "cross-check #{cross} via #{f['cross_check_platform']})"
    end

    def narrative_summary(record)
      data = (record["data"] || {}).except("brief", "searches", "prompt", "criteria",
                                           "prompts", "candidates", "findings", "axes")
      return "" if data.empty?

      data.map { |k, v| "#{k}=#{truncate(v.inspect, 400)}" }.join("  ·  ")
    end

    def prompt_for(record)
      record.dig("data", "prompt").presence ||
        record.dig("data", "brief").presence ||
        Array(record.dig("data", "prompts")).join("\n\n").presence
    end

    def searches_for(record)
      Array(record.dig("data", "searches")).select { |s| s.is_a?(Hash) }
    end

    def search_lines(search)
      lines = ["- **`#{search['query']}`**"]
      results = Array(search["results"]).select { |r| r.is_a?(Hash) }
      if results.any?
        results.each { |r| lines << "  - #{r['title'].to_s.strip.presence || r['url']} — #{r['url']}" }
      else
        Array(search["result_urls"]).each { |u| lines << "  - #{u}" }
      end
      Array(search["image_urls"]).each { |u| lines << "  - 🖼 #{u}" }
      lines
    end

    def step_images(record)
      case record["step_id"]
      when "A1"
        Array(record.dig("data", "candidates", "images")).filter_map { |i| i["url"] if i.is_a?(Hash) }
      when "C1"
        Array(record.dig("data", "candidate_urls"))
      when "P2_6"
        [record.dig("data", "composite_url")].compact
      when "P3_1b"
        (record.dig("data", "photos") || {}).values.compact
      else
        []
      end
    end

    # --- Shared helpers ----------------------------------------------------

    def a0_findings
      step_findings = step_dig("A0", "findings", "findings")
      return step_findings if step_findings.is_a?(Array)

      gate = HumanGate.where(step_id: "A0").order(:id).last
      return nil unless gate

      Array(JSON.parse(gate.agent_proposal || "{}").dig("findings", "findings"))
    end

    def spec
      @spec ||= KnowledgeBase::StyleSpec.load(@run.style_slug)
    rescue StandardError
      nil
    end

    def step_data(step_id)
      entry = Array(@run.step_results).find { |r| r["step_id"] == step_id }
      (entry && entry["data"] || {}).stringify_keys
    end

    def step_dig(step_id, *keys)
      step_data(step_id).dig(*keys)
    end

    # Copy a local image into the run's own directory and return a path relative to dossier.md, so
    # the report is self-contained and renders in any markdown viewer. Remote URLs pass through.
    def relative(original)
      return original if original.blank? || original.start_with?("http")

      target_dir = Rails.root.join("tmp", "runs", @run.run_id, "images")
      target_dir.mkpath
      target = target_dir.join(File.basename(original))
      FileUtils.cp(original, target) unless target.exist?
      "images/#{File.basename(original)}"
    rescue StandardError
      original
    end

    def message_for(step_id)
      entry = Array(@run.step_results).find { |r| r["step_id"] == step_id }
      entry && entry["message"]
    end

    def step_title(step_id)
      self.class.step_titles[step_id.to_s] || step_id.to_s
    end

    def self.step_titles
      @step_titles ||= begin
        raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
        %w[track_a track_b track_c].map { |t| raw.dig("phase_1", t, "steps") }
          .concat([raw.dig("phase_2", "steps"), raw.dig("phase_3_module_1", "steps")])
          .flatten.compact.to_h { |s| [s["id"], s["title"]] }
      end
    end

    def why_it_will_work
      claims = @run.qa_findings.where(severity: "pass", role: "proposer").pluck(:claim).uniq
      return "## Why we think this will work\nNo passing findings recorded." if claims.empty?

      "## Why we think this will work\n" + claims.map { |c| "- #{c}" }.join("\n")
    end

    def cannot_verify
      advisories = @run.qa_findings.where(severity: "advisory", role: "proposer").pluck(:claim).uniq
      return "## What we could not verify\nNone." if advisories.empty?

      "## What we could not verify\n" + advisories.map { |c| "- #{c}" }.join("\n")
    end

    def if_you_approve
      actions =
        case @run.scope
        when "style" then "writes the locked style spec to knowledge_base/ and commits it to git."
        when "full"  then "writes the locked style spec to knowledge_base/, commits it to git, and publishes to Etsy."
        else "commits the run and publishes to Etsy."
        end
      "## If you approve\nThe committed run replays: #{actions}"
    end

    def truncate(str, len = 120) = str.to_s.length > len ? str.to_s[0, len] + "…" : str.to_s
  end
end
