module Steps
  module Phase3
    class FillTags < Steps::Base
      step id: "P3_4", mechanism: :llm_text, ownership: "[AGENT-READY]"

      # context: { product_type: }
      def perform
        tag_rules = rules("etsy_tags").rules

        result = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                        .with_schema(Schemas::Phase3::TagsSchema)
                        .ask(prompt("p3_step4_tags",
                                    style_name: spec.name,
                                    content_type: piece.content_type,
                                    mood: piece.mood,
                                    color_role: piece.color_role_confirmed,
                                    room_type: piece.room_type,
                                    product_type: context.fetch(:product_type, "wall art print")))
                        .content

        tags = Array(result["tags"])
        errors = []

        errors << "expected #{tag_rules['slot_count']} tags, got #{tags.size}" unless tags.size == tag_rules["slot_count"]

        angles_covered = tags.map { |t| t["angle"] }.uniq.size
        min_angles = tag_rules["angle_diversity"]["validation"]["min_angles_covered"]
        errors << "only #{angles_covered} angles covered (need #{min_angles})" if angles_covered < min_angles

        # Near-duplicate check — normalize + compare
        normalized = tags.map { |t| t["tag"].to_s.downcase.gsub(/[^a-z0-9\s]/, "").split.sort.join(" ") }
        if normalized.uniq.size < normalized.size
          dups = normalized.tally.select { |_, c| c > 1 }.keys
          errors << "near-duplicate tags detected: #{dups.join(', ')}"
        end

        if errors.any?
          return needs_human("Tags failed validation: #{errors.join('; ')}",
                             { tags: tags, errors: errors })
        end

        piece.update!(listing_tags: tags.map { |t| t["tag"] })
        ok({ tags: tags.map { |t| t["tag"] }, angles_covered: angles_covered })
      end
    end
  end
end
