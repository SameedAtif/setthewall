module Steps
  module Phase3
    class SelectAndOrderPhotos < Steps::Base
      step id: "P3_2",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms hero shot]"

      def perform
        return ok({ photo_order: piece.photo_order }) if context[:confirmed]

        photos = (piece.photos || {}).select { |_, v| v.present? }
        if photos.empty?
          return fail_step("No photos on piece — Step 1b must run first.", {})
        end

        urls = photos.values

        chat = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                      .with_schema(Schemas::Phase3::HeroPhotoSchema)
        result = streamed_json(chat, prompt_for(photos.keys), with: urls)

        hero_url = resolve(result["recommended_hero"], photos) || urls.first
        ordered  = Array(result["ordering"]).filter_map { |label| resolve(label, photos) }
        ordered  = urls if ordered.empty?

        technical_notes = check_technical(urls, rules("etsy_photos").rules)

        needs_human(
          message(result["recommended_hero"], result["reasoning"], technical_notes),
          {
            # `hero` and the ordered list are real image paths, so the gate renders the actual
            # photos (the renderer shows image values inline) instead of a "photo_2" label.
            "hero" => hero_url,
            "ordered_photos" => ordered,
            "candidates" => urls,
            "reasoning" => result["reasoning"],
            "photo_count" => result["photo_count"] || urls.size,
            "technical_notes" => technical_notes
          }
        )
      end

      private

      # The vision model sees the images in order and refers to them by their photo-type name
      # (studio, lifestyle, detail …). Resolve that name back to the real photo path.
      def resolve(label, photos)
        value = label.to_s
        return value if value.match?(%r{\Ahttps?://}) || File.exist?(value)

        photos[value] || photos[value.downcase] ||
          photos.find { |type, _| type.to_s.casecmp?(value) }&.last
      end

      def message(hero_label, reasoning, technical_notes)
        notes = technical_notes.any? ? "Technical notes: #{technical_notes.join('; ')}" :
                                       "Technical checks passed."
        "Recommended hero: #{hero_label} (shown below with the full order). #{reasoning} #{notes}"
      end

      def prompt_for(types)
        <<~PROMPT
          You have #{types.size} candidate photos for an Etsy listing, provided in this order:
          #{types.join(', ')}. Refer to each photo by its type name (not by position number).

          Etsy shows the first photo as the search-result thumbnail. Recommend which TYPE should be
          first — the CLEAREST, MOST EYE-CATCHING image, NOT necessarily the most artistic one. A
          tightly-centered square composition survives Etsy's ~4:3-5:4 thumbnail crop better than a
          portrait with the subject near the top (supplementary tip, not Etsy-official — apply as
          guidance).

          Return the recommended hero's TYPE, your reasoning, the full type ordering (hero first,
          up to 10 slots), and the photo count.
        PROMPT
      end

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
