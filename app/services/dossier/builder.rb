module Dossier
  # Module 09 §8 — assembles the reviewable report from the run, its escalations, and its QA
  # findings. Ordering is deliberate: open questions come second, before the step-by-step, and the
  # report never opens with cost or duration (SR4).
  class Builder
    def self.call(run:) = new(run).call

    def initialize(run) = @run = run

    def call
      [
        header,
        open_questions,
        research,
        style_spec,
        step_by_step,
        why_it_will_work,
        cannot_verify,
        if_you_approve
      ].join("\n\n")
    end

    private

    def header
      "# Run #{@run.run_id} — #{@run.style_slug} / #{@run.scene_spec_id}\n" \
      "Mode: #{@run.mode} · KB version: #{@run.kb_version} · Status: #{@run.status}"
    end

    def open_questions
      escalations = Array(@run.escalations)
      return "## Open questions\nNone." if escalations.empty?

      "## Open questions\n" + escalations.map { |e| "- #{e['step_id']}: #{e['reason']}" }.join("\n")
    end

    def research
      "## The research behind this style\nSee step-by-step for A0/A1 findings and search counts."
    end

    def style_spec
      "## The style spec we are running against\n#{@run.style_slug}"
    end

    def step_by_step
      rows = Array(@run.step_results).map do |r|
        suffix = r["verdict"] ? " (#{r['verdict']} → #{r['disposition']})" : ""
        "- #{r['step_id']}: #{r['status']}#{suffix}"
      end
      "## Step by step\n" + rows.join("\n")
    end

    def why_it_will_work
      claims = @run.qa_findings.where(severity: "pass").map { |f| "- #{f.claim}" }
      return "## Why we think this will work\nNo passing findings recorded." if claims.empty?

      "## Why we think this will work\n" + claims.join("\n")
    end

    def cannot_verify
      advisories = @run.qa_findings.where(severity: "advisory").map { |f| "- #{f.claim}" }
      return "## What we could not verify\nNone." if advisories.empty?

      "## What we could not verify\n" + advisories.join("\n")
    end

    def if_you_approve
      "## If you approve\nThe committed run replays: writes specs to knowledge_base/, commits to git, " \
      "and publishes to Etsy."
    end
  end
end
