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
                                    style_name: spec.display_name,
                                    demand_terms: TrackAResearch.demand_terms_text,
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

        # Breadth cap — at most 4 broad tags, the rest long-tail
        broad_count = tags.count { |t| t["breadth"] == "broad" }
        errors << "#{broad_count} broad tags (max 4)" if broad_count > 4

        # Style descriptor must be embedded in room/gift/alternate tags — matched against the
        # style's whole vocabulary (display name + A0 demand terms), not one literal word.
        tokens = style_descriptor_tokens
        unless tokens.empty?
          bare = tags.select { |t| %w[room_or_space_use gift_or_occasion alternate_use].include?(t["angle"]) }
                     .reject { |t| tag_has_style?(t["tag"], tokens) }
          errors << "room/gift/alternate tags missing style descriptor: #{bare.map { |t| t['tag'] }.join(', ')}" if bare.any?
        end

        if errors.any?
          return needs_human("Tags failed validation: #{errors.join('; ')}",
                             { tags: tags, errors: errors })
        end

        piece.update!(listing_tags: tags.map { |t| t["tag"] })
        ok({ tags: tags.map { |t| t["tag"] }, angles_covered: angles_covered })
      end

      private

      def style_descriptor_tokens
        stop = %w[and the for with from of in on to a an their its or
                  print prints wall art decor home poster]
        ([spec.display_name.to_s] + TrackAResearch.demand_terms)
          .flat_map { |t| t.to_s.downcase.split(/[^a-z0-9]+/) }
          .reject { |w| w.blank? || stop.include?(w) }
          .uniq
      end

      def tag_has_style?(tag, tokens)
        (tag.to_s.downcase.split(/[^a-z0-9]+/) & tokens).any?
      end
    end
  end
end
