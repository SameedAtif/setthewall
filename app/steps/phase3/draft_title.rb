module Steps
  module Phase3
    class DraftTitle < Steps::Base
      step id: "P3_3", mechanism: :llm_text, ownership: "[AGENT-READY]"

      # context: { product_type: (e.g. "print", "framed print", "digital download") }
      def perform
        title_rules = rules("etsy_title").rules

        result = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                        .with_schema(Schemas::Phase3::TitleSchema)
                        .ask(prompt("p3_step3_title",
                                    style_name: spec.display_name,
                                    demand_terms: TrackAResearch.demand_terms_text,
                                    content_type: piece.content_type,
                                    mood: piece.mood,
                                    color_role: piece.color_role_confirmed,
                                    room_type: piece.room_type,
                                    product_type: context.fetch(:product_type, "wall art print")))
                        .content

        title = result["title"]
        errors = validate_title(title, result, title_rules)

        if errors.any?
          return needs_human(
            "Title draft failed validation: #{errors.join('; ')}. Draft was: #{title.inspect}",
            { title: title, errors: errors, raw: result }
          )
        end

        piece.update!(listing_title: title)
        ok({ title: title, first_six_words: result["first_six_words"] })
      end

      private

      def validate_title(title, result, rules)
        errors = []
        return ["title blank"] if title.blank?

        # Exclude subjective adjectives
        subjective = /\b(beautiful|perfect|stunning|amazing|gorgeous|lovely|breathtaking)\b/i
        errors << "contains subjective adjective(s) — banned by rules.exclude" if title.match?(subjective)

        # Exclude price signals
        errors << "contains a price ($ or price-like number)" if title.match?(/\$|\bprice\b/i)

        # Exclude ALL CAPS multi-word phrases
        errors << "contains ALL CAPS phrase (marketing shout)" if title.match?(/\b[A-Z]{4,}\s+[A-Z]{4,}\b/)

        # Emoji check — Unicode symbols outside basic Latin
        errors << "contains emoji or decorative symbols" if title.match?(/[^\x00-\x7F]/) &&
                                                            !title.match?(/[àâäéèêëîïôöùûüç]/i)

        # First-six-words descriptor test — enforced literally
        first_six = title.split.first(6).join(" ")
        if result["first_six_words"] != first_six
          errors << "reported first_six_words doesn't match actual first six of title"
        end

        errors
      end
    end
  end
end
