module Steps
  module Phase2
    class UnifyByTheme < Steps::Base
      step id: "P2_3",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — vision check, human confirms]"

      def perform
        # Only applies to multi-piece sets
        if piece.piece_count.to_i <= 1
          return ok({ skipped: true, reason: "Single piece — theme unification is a set-level check" })
        end

        set_urls = piece.finalist_urls.presence || [piece.chosen_url].compact
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::Phase2::ThemeUnificationSchema)
                        .ask(prompt("p2_step3_theme_unification",
                                    piece_count: set_urls.size, style_name: spec.name),
                             with: set_urls)
                        .content

        if result["fails_count"].to_i.positive?
          return needs_human(
            "Theme-unification check failed on #{result['fails_count']} criterion/criteria. " \
            "Shared thread claim: #{result['shared_thread']}. Reads as one collection: " \
            "#{result['reads_as_one_collection']}. Human confirms whether to proceed with this " \
            "set or return to Track C for a tighter cull.",
            { llm_result: result }
          )
        end

        ok({ shared_thread: result["shared_thread"],
             reads_as_one_collection: result["reads_as_one_collection"] })
      end
    end
  end
end
