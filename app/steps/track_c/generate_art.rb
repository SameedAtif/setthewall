module Steps
  module TrackC
    class GenerateArt < Steps::Base
      step id: "C1",
           mechanism: :image_gen,
           ownership: "[AGENT-ASSISTED — human enforces batch cap]"

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

        adapter = ImageGeneration::Adapter.build
        urls = []
        prompt_files = []
        contributions = []
        prompts = []

        pairs.each do |pair|
          synthesis = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                             .with_schema(Schemas::TrackC::PromptSynthesisSchema)
                             .ask(build_synthesis_prompt(pair)).content

          gen_prompt = synthesis["image_generation_prompt"]
          prompts << gen_prompt
          contributions.concat(Array(synthesis["axis_contributions"]))

          result = adapter.generate(prompt: gen_prompt, n: 1)
          urls.concat(result.urls)
          if result.raw_response.is_a?(Hash) && result.raw_response[:prompt_file]
            prompt_files << result.raw_response[:prompt_file]
          end
        end

        piece.update!(
          batch_count: want,
          candidate_urls: urls,
          candidate_subjects: pairs.map { |p| p[:subject] && p[:subject]["subject"] },
          candidate_patterns: pairs.map { |p| p[:pattern] && p[:pattern]["pattern_id"] }
        )

        if prompt_files.any?
          needs_human(
            "IMAGE_GEN_PROVIDER=manual: generate #{want} candidates from the prompt file(s) at " \
            "#{prompt_files.join(', ')} and paste the resulting image URLs back into this piece.",
            { prompt_files: prompt_files, n_requested: want, adapter: adapter.name, prompts: prompts }
          )
        else
          ok({ candidate_urls: urls, adapter: adapter.name,
               axis_contributions: contributions, prompts: prompts })
        end
      end

      private

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
