module Dossier
  # Module 09 §8 — assembles the reviewable report from the run, its escalations, its QA findings,
  # the piece's outputs, the locked style spec, and the A0 research gate. Ordering is deliberate:
  # open questions come second, before the step-by-step, and the report never opens with cost or
  # duration (SR4). Images are embedded as markdown so the report reads as a document.
  class Builder
    def self.call(run:) = new(run).call

    def initialize(run) = @run = run

    def call
      [
        header,
        what_we_propose,
        open_questions,
        research,
        style_spec,
        images,
        step_by_step,
        why_it_will_work,
        cannot_verify,
        if_you_approve
      ].join("\n\n")
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

      rows = escalations.map do |e|
        detail = e["divergence"] ? " (proposer: #{e["divergence"]["proposer"]}, verifier: #{e["divergence"]["verifier"]})" : ""
        "- **#{e["step_id"]}:** #{e["reason"]}#{detail}"
      end
      "## Open questions\n" + rows.join("\n")
    end

    def research
      "## The research behind this style\n" + research_lines.join("\n")
    end

    def research_lines
      gate = HumanGate.where(step_id: "A0").order(:id).last
      return ["No A0 research gate recorded for this style yet."] unless gate

      proposal = JSON.parse(gate.agent_proposal || "{}")
      findings = Array(proposal.dig("findings", "findings"))
      return ["A0 returned no demand-to-competition findings."] if findings.empty?

      findings.map do |f|
        cross = f["cross_check_confirmed"] ? "confirmed" : "not confirmed"
        "- **#{f['theme']}** — #{f['demand_to_competition_verdict']} " \
        "(shops: #{f['independent_shops']}, competition: #{f['competition_density']}, " \
        "cross-check #{cross} via #{f['cross_check_platform']})"
      end
    end

    def style_spec
      spec = KnowledgeBase::StyleSpec.load(@run.style_slug)
      scene = spec.scene(@run.scene_spec_id)

      lines = ["## The style spec we are running against"]
      spec.style_level.each { |axis, value| lines << "- **#{axis}:** #{value}" }
      lines << "- **scene (#{@run.scene_spec_id}):** wall_condition=#{scene.wall_condition}, " \
                "furniture_weight=#{scene.furniture_weight}, room_type=#{scene.room_type}, " \
                "room_shape=#{scene.room_shape}, space_math=#{scene.space_math}, " \
                "color_role=#{scene.color_role}"
      lines.join("\n")
    rescue StandardError
      "## The style spec we are running against\n#{@run.style_slug}"
    end

    def images
      lines = ["## Images"]
      lines << "### The piece placed in the scene (composite)"
      lines << (piece&.composite_url.presence ? "![composite](#{piece.composite_url})" : "_(none)_")
      lines << "### The chosen piece (art only)"
      lines << (piece&.chosen_url.presence ? "![chosen](#{piece.chosen_url})" : "_(none)_")
      lines << "### Candidate batch"
      candidates = Array(piece&.candidate_urls)
      if candidates.empty?
        lines << "_(none)_"
      else
        candidates.each_with_index { |url, i| lines << "![candidate #{i + 1}](#{url})" }
      end
      lines << "### Lifestyle photos"
      photos = (piece&.photos || {}).select { |_, v| v.present? }
      photos.empty? ? lines << "_(none)_" : photos.each { |k, v| lines << "![#{k}](#{v})" }
      lines.join("\n")
    end

    def step_by_step
      rows = Array(@run.step_results).map do |r|
        verdict = r["verdict"] ? " (#{r["verdict"]} → #{r["disposition"]})" : ""
        detail = step_detail(r)
        "- **#{r["step_id"]}:** #{r["status"]}#{verdict}#{detail}"
      end
      "## Step by step\n" + rows.join("\n")
    end

    def step_detail(record)
      data = (record["data"] || {}).except("error", "criteria", "brief")
      return "" if data.empty?

      summary = data.map { |k, v| "#{k}=#{truncate(v.inspect)}" }.join(", ")
      " — #{summary}"
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
      "## If you approve\nThe committed run replays: writes specs to knowledge_base/, commits to git, " \
      "and publishes to Etsy."
    end

    def truncate(str, len = 120) = str.to_s.length > len ? str.to_s[0, len] + "…" : str.to_s
  end
end
