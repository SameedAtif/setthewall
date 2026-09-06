module Context
  # Builds a step's context from prior step results. This is the cross-step carry-forward for the
  # conductor (the piece-pipeline equivalent of module 01c's TrackASequence::SOURCES). The mapping
  # below covers Track A; extending it across B/C/P2/P3 is a follow-up — unlisted steps get the
  # run's base context only.
  class Assembler
    SOURCES = {
      "A1" => { style_name: ["A0", "style_name_used"] },
      "A2" => { reference_images: ["A1", "curated_images"] },
      "A3" => { reference_images: ["A1", "curated_images"] },
      "A4" => { reference_images: ["A1", "curated_images"], mood: ["A2", "mood"] },
      "A5" => { style_name: ["A0", "style_name_used"], mood: ["A2", "mood"],
                content_type: ["A3", "content_type"], frame_form: ["A4", "frame_form"] }
    }.freeze

    def self.for(step_id, run)
      return c2_context(run) if step_id == "C2"

      results = results_by_step(run)
      derived = SOURCES.fetch(step_id, {}).each_with_object({}) do |(key, (from, result_key)), ctx|
        value = results.dig(from, result_key)
        ctx[key] = value unless value.nil?
      end

      base = { style_slug: run.style_slug, scene_spec_id: run.scene_spec_id }.compact
      base.merge(derived)
    end

    # C2's cull + pick is a human decision. For a speculative run, provisionally auto-pick the
    # first finalists and the first as chosen so Phase 2/3 can proceed; the human reviews and
    # overrides via the dossier.
    def self.c2_context(run)
      candidates = Array(run.piece_record&.candidate_urls)
      return {} if candidates.empty?

      finalists = candidates.first(3)
      { finalist_urls: finalists, chosen_url: finalists.first }
    end

    def self.results_by_step(run)
      Array(run.step_results).each_with_object({}) do |r, acc|
        acc[r["step_id"]] = (r["data"] || {}).stringify_keys if r["step_id"]
      end
    end
  end
end
