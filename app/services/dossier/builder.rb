module Dossier
  # Module 09 §8 — assembles the reviewable report from the run, its escalations, its QA findings,
  # the piece's outputs, the locked style spec, and the A0 research gate. Ordering is deliberate:
  # open questions come second, before the step-by-step, and the report never opens with cost or
  # duration (SR4). Images are embedded as markdown so the report reads as a document.
  class Builder
    def self.call(run:) = new(run).call

    def initialize(run) = @run = run

    def call
      sections = [header]
      sections << what_we_propose if piece
      sections.concat([open_questions, research, the_style, the_scene,
                       images, step_by_step, why_it_will_work, cannot_verify, if_you_approve])
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
      findings = a0_findings
      return ["No A0 research recorded for this style yet."] if findings.nil?
      return ["A0 returned no demand-to-competition findings."] if findings.empty?

      findings.map do |f|
        cross = f["cross_check_confirmed"] ? "confirmed" : "not confirmed"
        "- **#{f['theme']}** — #{f['demand_to_competition_verdict']} " \
        "(shops: #{f['independent_shops']}, competition: #{f['competition_density']}, " \
        "cross-check #{cross} via #{f['cross_check_platform']})"
      end
    end

    def a0_findings
      step_findings = step_dig("A0", "findings", "findings")
      return step_findings if step_findings.is_a?(Array)

      gate = HumanGate.where(step_id: "A0").order(:id).last
      return nil unless gate

      Array(JSON.parse(gate.agent_proposal || "{}").dig("findings", "findings"))
    end

    def the_style
      lines = ["## The style"]
      lines << "- **mood:** #{style_value(:mood, 'A2') || '—'}"
      lines << "- **content_type:** #{style_value(:content_type, 'A3') || '—'}"
      lines << "- **frame_form:** #{style_value(:frame_form, 'A4') || '—'}"
      lines.join("\n")
    end

    def the_scene
      lines = ["## The scene (#{@run.scene_spec_id})"]
      { wall_condition: "B1", furniture_weight: "B2", room_type: "B3",
        room_shape: "B4", space_math: "B5", color_role: "B6" }.each do |axis, step|
        value = step_dig(step, axis.to_s).presence || committed_scene_axis(axis)
        lines << "- **#{axis}:** #{value || '—'}"
      end
      lines.join("\n")
    end

    def style_value(axis, step)
      step_dig(step, "result", axis.to_s).presence || spec&.style_level&.[](axis)
    rescue StandardError
      nil
    end

    def committed_scene_axis(axis)
      spec&.scene(@run.scene_spec_id)&.public_send(axis)
    rescue StandardError
      nil
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

    def images
      lines = ["## Images"]
      lines << "### The piece placed in the scene (composite)"
      lines << (piece&.composite_url.presence ? "![composite](#{relative(piece.composite_url)})" : "_(none)_")
      lines << "### The chosen piece (art only)"
      lines << (piece&.chosen_url.presence ? "![chosen](#{relative(piece.chosen_url)})" : "_(none)_")
      lines << "### Candidate batch"
      candidates = Array(piece&.candidate_urls)
      if candidates.empty?
        lines << "_(none)_"
      else
        candidates.each_with_index { |url, i| lines << "![candidate #{i + 1}](#{relative(url)})" }
      end
      lines << "### Lifestyle photos"
      photos = (piece&.photos || {}).select { |_, v| v.present? }
      photos.empty? ? lines << "_(none)_" : photos.each { |k, v| lines << "![#{k}](#{relative(v)})" }
      lines.join("\n")
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
