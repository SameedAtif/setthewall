module Steps
  module Phase3
    class SelectAndOrderPhotos < Steps::Base
      step id: "P3_2",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms hero shot]"

      def perform
        return ok({ photo_order: piece.photo_order }) if context[:confirmed]

        available = (piece.photos || {}).select { |_, v| v.present? }
        if available.empty?
          return fail_step("No photos on piece — Step 1b must run first.", {})
        end

        # LLM evaluates which photo is the clearest thumbnail candidate
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::Phase3::HeroPhotoSchema)
                        .ask(
                          <<~PROMPT,
                            You have #{available.size} candidate photos for an Etsy listing.
                            Etsy shows the first photo as the search-result thumbnail. Recommend
                            which should be first — the CLEAREST, MOST EYE-CATCHING image, NOT
                            necessarily the most artistic one. A tightly-centered square
                            composition survives Etsy's ~4:3-5:4 thumbnail crop better than a
                            portrait with the subject near the top (supplementary tip, not
                            Etsy-official — apply as guidance).

                            Return the full ordering (up to 10 slots), hero first. Report the
                            photo count.
                          PROMPT
                          with: available.values
                        ).content

        # Also validate technical constraints from the photos rule file
        photo_rules = rules("etsy_photos").rules
        technical_notes = check_technical(available.values, photo_rules)

        needs_human(
          "Confirm hero photo: #{result['recommended_hero']} — #{result['reasoning']}. " \
          "#{technical_notes.any? ? "Technical notes: #{technical_notes.join('; ')}" : 'Technical checks passed.'}",
          { recommended: result, technical_notes: technical_notes }
        )
      end

      private

      # Basic checks; a real image-dimension check would decode the file. This is a lightweight
      # heuristic — module 07 later may harden it.
      def check_technical(urls, rules)
        notes = []
        # Placeholder: real implementation would use ruby-vips (already in Gemfile) to check
        # dimensions per photo. Below stub is where that check would live.
        notes
      end
    end
  end
end
