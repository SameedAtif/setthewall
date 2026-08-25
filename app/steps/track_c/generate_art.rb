module Steps
  module TrackC
    class GenerateArt < Steps::Base
      step id: "C1",
           mechanism: :image_gen,
           ownership: "[AGENT-ASSISTED — human enforces batch cap]"

      # context: { candidate_count: (optional Integer) }
      # piece: a fresh PieceRecord with style_spec_slug and scene_spec_id set — apply_spec!
      #        must have been called on it already so the axis values are denormalised.
      def perform
        constraints = rules("generation_constraints").rules
        cap  = constraints["batch"]["max_candidates_per_scene"]
        want = [context.fetch(:candidate_count, cap).to_i, cap].min

        if want < 1
          return fail_step("candidate_count must be at least 1", { requested: context[:candidate_count] })
        end

        # === Step 1 — synthesise the prompt ===
        synthesis = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                           .with_schema(Schemas::TrackC::PromptSynthesisSchema)
                           .ask(build_synthesis_prompt).content

        gen_prompt = synthesis["image_generation_prompt"]

        # === Step 2 — call the image generator ===
        adapter = ImageGeneration::Adapter.build
        result  = adapter.generate(prompt: gen_prompt, n: want)

        # Persist the prompt on the piece regardless of adapter outcome, so it's reproducible
        # and available for the review UI even in the manual case.
        piece.update!(
          batch_count: want,
          candidate_urls: result.urls
        )

        if result.raw_response.is_a?(Hash) && result.raw_response[:pending]
          needs_human(
            "IMAGE_GEN_PROVIDER=manual: generate #{want} candidates from the prompt at " \
            "#{result.raw_response[:prompt_file]} and paste the resulting image URLs back " \
            "into this piece via candidate_urls.",
            { prompt_file: result.raw_response[:prompt_file],
              n_requested: want, adapter: adapter.name, prompt: gen_prompt }
          )
        else
          ok({
            candidate_urls: result.urls,
            estimated_cost_usd: result.estimated_cost_usd,
            adapter: adapter.name,
            prompt: gen_prompt,
            axis_contributions: synthesis["axis_contributions"]
          })
        end
      end

      private

      def build_synthesis_prompt
        prompt("c1_generation_prompt_synthesis",
               style_name:   spec.name,
               mood:         piece.mood,
               content_type: piece.content_type,
               frame_form:   piece.frame_form,
               color_role:   piece.color_role,
               room_shape:   piece.room_shape)
      end
    end
  end
end
