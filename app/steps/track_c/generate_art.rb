module Steps
  module TrackC
    class GenerateArt < Steps::Base
      step id: "C1",
           mechanism: :image_gen,
           ownership: "[AGENT-ASSISTED — human enforces batch cap]"

      # Safety net for a single candidate (synthesis + one image call). The synthesis already has
      # the no-progress watchdog; this also bounds a hung image call.
      DEFAULT_PAIR_TIMEOUT = 1800

      # How many of A1's reference images to hand the image provider as style references. Keep it
      # small: each reference is inlined into every candidate call, so this multiplies token cost.
      DEFAULT_STYLE_REFERENCE_LIMIT = 4

      # context: { candidate_count: (optional Integer) }
      def perform
        constraints = rules("generation_constraints").rules
        cap  = constraints["batch"]["max_candidates_per_scene"]
        want = [context.fetch(:candidate_count, cap).to_i, cap].min

        if want < 1
          return fail_step("candidate_count must be at least 1", { requested: context[:candidate_count] })
        end

        # Selection happens in code, one (subject, pattern) pair per batch item, so the synthesis
        # call never sees a list to blend.
        pairs = Art::SubjectSceneSelector.pairs(spec, want)

        # Build every synthesis prompt up front — reading the spec/piece happens only on the main
        # thread — then run the independent candidates concurrently. Each candidate is a long
        # streaming synthesis followed by one image call, so a bounded pool collapses the wall time
        # without changing any prompt, model, or schema (quality is untouched; we still never show
        # the synthesis call a list to blend).
        synthesis_prompts = pairs.map { |pair| build_synthesis_prompt(pair) }
        style_references = style_reference_images
        results = synthesize_and_generate(synthesis_prompts, style_references)
        prompt_log = write_prompt_log(pairs, results)

        succeeded = results.select { |r| r[:ok] }
        failed    = results.reject { |r| r[:ok] }

        if succeeded.empty?
          return fail_step(
            "Image generation produced no candidates (#{failed.size}/#{pairs.size} failed)",
            { failures: failed.map { |r| { index: r[:index], error: r[:error] } },
              image_prompt_log: prompt_log, style_reference: style_references }
          )
        end

        if failed.any?
          Workflow::StepLogging.log(
            "#{failed.size}/#{pairs.size} candidate(s) failed: " +
            failed.map { |r| "##{r[:index]} #{r[:error]}" }.join("; "), level: :warn
          )
        end

        urls            = succeeded.flat_map { |r| r[:urls] }
        prompt_files    = succeeded.filter_map { |r| r[:prompt_file] }
        gen_prompts     = succeeded.map { |r| r[:prompt] }
        contributions   = succeeded.flat_map { |r| r[:contributions] }
        candidate_pairs = succeeded.map { |r| pairs[r[:index]] }
        adapter_name    = succeeded.first[:adapter]

        piece.update!(
          batch_count: succeeded.size,
          candidate_urls: urls,
          candidate_subjects: candidate_pairs.map { |p| p[:subject] && p[:subject]["subject"] },
          candidate_patterns: candidate_pairs.map { |p| p[:pattern] && p[:pattern]["pattern_id"] }
        )

        if prompt_files.any?
          needs_human(
            "IMAGE_GEN_PROVIDER=manual: generate #{want} candidates from the prompt file(s) at " \
            "#{prompt_files.join(', ')} and paste the resulting image URLs back into this piece.",
            { prompt_files: prompt_files, n_requested: want, adapter: adapter_name,
              prompts: gen_prompts, image_prompt_log: prompt_log,
              style_reference: style_references }
          )
        else
          ok({ candidate_urls: urls, adapter: adapter_name,
               axis_contributions: contributions, prompts: gen_prompts,
               requested: want, generated: urls.size,
               failures: failed.map { |r| { index: r[:index], error: r[:error] } },
               image_prompt_log: prompt_log, style_reference: style_references })
        end
      end

      private

      # Runs each candidate on its own thread. Full parallelism by default (one thread per
      # candidate, up to the batch cap); lower it with C1_CONCURRENCY if a provider rate-limits.
      # Results carry their original index and are re-sorted, so the persisted batch order is
      # deterministic regardless of completion order. Failures are data, not exceptions, so one
      # bad candidate cannot abort the rest.
      def synthesize_and_generate(synthesis_prompts, style_references)
        size        = synthesis_prompts.size
        concurrency = ENV.fetch("C1_CONCURRENCY", size).to_i.clamp(1, size)
        Workflow::StepLogging.log("Synthesising and generating #{size} candidate(s) " \
                                  "(concurrency #{concurrency})")
        sink = Workflow::StepLogging.current

        pool = Concurrent::FixedThreadPool.new(concurrency)
        futures = synthesis_prompts.each_with_index.map do |prompt, index|
          Concurrent::Future.execute(executor: pool) do
            Workflow::StepLogging.with_logger(sink) { run_candidate(prompt, index, style_references) }
          end
        end

        # Concurrent::Future#value(timeout) returns nil (it does not raise) when the timeout is
        # reached, so a hung candidate yields nil rather than an exception. Wait against one shared
        # deadline so the whole batch is bounded, and turn a nil into a normal failed result.
        deadline = monotonic + pair_timeout
        futures.each_with_index.map do |future, index|
          remaining = deadline - monotonic
          future.value(remaining.positive? ? remaining : 0) || timeout_result(index)
        end.sort_by { |result| result[:index] }
      ensure
        if pool
          pool.shutdown
          pool.kill unless pool.wait_for_termination(5)
        end
      end

      def timeout_result(index)
        { index: index, ok: false, error: "timed out after #{pair_timeout}s" }
      end

      def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      def run_candidate(synthesis_prompt, index, style_references = [])
        adapter = ImageGeneration::Adapter.build
        chat = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                      .with_schema(Schemas::TrackC::PromptSynthesisSchema)
        synthesis = Pipeline::Streaming.ask(chat, synthesis_prompt).content

        # A streamed synthesis can come back as an unparsed string (or a hash missing the key).
        # Never hand the image API a blank/garbage prompt — that is how off-style stock imagery
        # slips in. Treat it as a failed candidate instead.
        unless synthesis.is_a?(Hash) && synthesis["scene_description"].present?
          raise "synthesis produced no scene_description (got #{synthesis.class})"
        end

        scene = synthesis["scene_description"].to_s
        image_prompt = build_image_prompt(scene)
        result = adapter.generate(prompt: image_prompt, n: 1, style_reference: style_references)

        {
          index: index, ok: true,
          scene_description: scene,
          prompt: image_prompt,
          contributions: image_prompt_contributions,
          style_reference: style_references,
          urls: Array(result.urls),
          prompt_file: (result.raw_response.is_a?(Hash) ? result.raw_response[:prompt_file] : nil),
          adapter: adapter.name
        }
      rescue StandardError => e
        { index: index, ok: false, error: "#{e.class}: #{e.message}" }
      end

      # The final image-generation prompt is assembled deterministically: the LLM supplies only the
      # scene description, while the axis directives and negative clause come from
      # generation_prompt_template.yml via knowledge_base/prompts/c1_image_prompt.md. Tuning the
      # prompt is a KB file edit, not a code change, and the negatives can never be dropped.
      # NOTE: content_type's rendering directive is deliberately omitted from the image prompt for
      # now (A/B test). image_prompt_directives still resolves it, so re-adding is one template edit.
      def build_image_prompt(scene)
        d = image_prompt_directives
        prompt("c1_image_prompt",
               scene: scene,
               reference_essence: reference_essence_clause,
               color_treatment: d["color_role"],
               palette: d["mood"],
               line_constraint: room_shape_constraint.presence || "",
               negative_prompt: d["negative_prompt"])
      end

      # A1's account of what the reference set shares (medium, palette, texture, motifs, mood). We
      # ask for an original piece in the same tradition — never a copy of any single reference.
      def reference_essence_clause
        essence = context[:reference_essence] || {}
        qualities = Array(essence[:qualities]).map(&:to_s).reject(&:blank?)
        mood = essence[:mood].to_s.presence
        return "" if qualities.empty? && mood.blank?

        details = []
        details << "dominant mood: #{mood}" if mood
        details.concat(qualities)
        "Build an original piece in the same tradition as the reference set — same medium, palette, " \
          "surface treatment, level of abstraction and motif grammar — as a NEW composition, never " \
          "a copy of any single reference. Take only the ARTWORK from the description below, not " \
          "how it is displayed: ignore framing, matting, styling and room context. What the " \
          "reference artwork shares: #{details.join(' ')}"
      end

      def image_prompt_directives
        directives = rules("generation_prompt_template").rules
        axes = Array(directives["directive_axes"]).index_by { |axis| axis["axis"] }
        {
          "content_type" => axes.dig("content_type", "values", piece.content_type) || piece.content_type.to_s,
          "color_role"   => axes.dig("color_role", "values", piece.color_role) || piece.color_role.to_s,
          "mood"         => axes.dig("mood", "values", piece.mood) || piece.mood.to_s,
          "negative_prompt" => directives.dig("constraints", "negative_prompt").to_s.strip
        }
      end

      def image_prompt_contributions
        d = image_prompt_directives
        [
          { axis: "color_role", phrase_added: d["color_role"] },
          { axis: "mood", phrase_added: d["mood"] },
          { axis: "room_shape", phrase_added: room_shape_constraint.presence }
        ].reject { |c| c[:phrase_added].blank? }
      end

      # Durable record of every synthesized image prompt — subject/pattern, the exact prompt sent
      # to the image API, the negative clause, axis contributions and outcome — so prompt quality
      # can be studied and the template improved. Written on the main thread after the pool closes.
      def write_prompt_log(pairs, results)
        dir = Rails.root.join("tmp", "c1_prompts")
        dir.mkpath
        file = dir.join("piece_#{piece.id}_#{Time.current.strftime('%Y%m%dT%H%M%S')}.jsonl")

        File.open(file, "w") do |f|
          results.sort_by { |r| r[:index] }.each do |r|
            pair = pairs[r[:index]] || {}
            f.puts(JSON.generate(
              "index" => r[:index],
              "subject" => pair[:subject] && pair[:subject]["subject"],
              "pattern_id" => pair[:pattern] && pair[:pattern]["pattern_id"],
              "scene_description" => r[:scene_description],
              "image_generation_prompt" => r[:prompt],
              "axis_contributions" => r[:contributions],
              "style_reference" => r[:style_reference],
              "urls" => r[:urls],
              "ok" => r[:ok] == true,
              "error" => r[:error]
            ))
          end
        end

        Workflow::StepLogging.log("Image prompt log written: #{file} (#{results.size} candidate(s))")
        file.to_s
      end

      def pair_timeout = ENV.fetch("C1_PAIR_TIMEOUT", DEFAULT_PAIR_TIMEOUT).to_i

      # A1's reference set, localized to disk so providers that inline images (Gemini) can use them.
      # Resolved once on the main thread before the pool, so the downloads happen once per run.
      def style_reference_images
        urls = Array(context[:reference_images]).first(style_reference_limit)
        return [] if urls.empty?

        localized = localize_images(urls)
        Workflow::StepLogging.log("Using #{localized.size} style reference image(s)")
        localized
      end

      def style_reference_limit
        ENV.fetch("C1_STYLE_REFERENCE_LIMIT", DEFAULT_STYLE_REFERENCE_LIMIT).to_i.clamp(0, 12)
      end

      def build_synthesis_prompt(pair)
        base = { style_name: spec.display_name, mood: piece.mood,
                 content_type: piece.content_type, color_role: piece.color_role }

        if pair[:subject].present? && pair[:pattern].present?
          prompt("c1_generation_prompt_synthesis_scene",
                 **base,
                 recurring_subject: pair[:subject]["subject"],
                 narrative_structure: pair[:pattern]["narrative_structure"],
                 light_logic: pair[:pattern]["light_logic"],
                 temporal_quality: pair[:pattern]["temporal_quality"],
                 room_shape_constraint: room_shape_constraint)
        else
          prompt("c1_generation_prompt_synthesis", **base, room_shape: piece.room_shape)
        end
      end

      def room_shape_constraint
        case piece.room_shape
        when "narrow"          then "compose with strong vertical lines."
        when "low_ceilinged"   then "compose with strong horizontal lines."
        when "small_closed_in" then "keep the composition open and uncluttered, with visual breathing room."
        else ""
        end
      end
    end
  end
end
