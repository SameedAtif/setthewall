module Steps
  module Phase3
    class WriteDescription < Steps::Base
      step id: "P3_6", mechanism: :llm_text, ownership: "[AGENT-ASSISTED — human confirms tone]"

      # context: { product_type:, dimensions:, sizes:, included:, fulfillment_type:,
      #            turnaround_days:, positioning_target: (specific 'who is this for' string) }
      def perform
        return ok({ description: piece.listing_description }) if context[:confirmed]

        dimensions = context[:dimensions]
        sizes      = context[:sizes]
        if dimensions.blank? || sizes.blank?
          return fail_step(
            "Cannot write a description — dimensions and sizes must be known before the model " \
            "can write non-contradictory copy.",
            { dimensions: dimensions, sizes: sizes }
          )
        end

        if (dims = parsed_inches(dimensions)) &&
           Art::PrintResolution.oversized?(width_in: dims[0], height_in: dims[1])
          return fail_step(
            "Offered dimensions #{dimensions} exceed the generator's honest print ceiling " \
            "(max #{Art::PrintResolution.max_inches_per_dimension.round(1)}\" per side at 300 DPI).",
            { dimensions: dimensions }
          )
        end

        chat = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                      .with_schema(Schemas::Phase3::DescriptionSchema)
        result = streamed_json(chat, prompt("p3_step6_description",
                                            style_name: spec.display_name,
                                            content_type: piece.content_type,
                                            mood: piece.mood,
                                            color_role: piece.color_role_confirmed,
                                            product_type: context.fetch(:product_type, "wall art print"),
                                            dimensions: dimensions,
                                            sizes: sizes,
                                            included: context.fetch(:included, "Print only"),
                                            fulfillment_type: context.fetch(:fulfillment_type, piece.fulfillment_type.presence || "physical"),
                                            turnaround_days: context.fetch(:turnaround_days, 3),
                                            positioning_target: context.fetch(:positioning_target, default_positioning_target),
                                            trend_evidence: trend_evidence))

        # Validate keyword-stuffing: no tag phrase used more than 2× in the description
        stuffing_violations = check_keyword_stuffing(result["full_description"], piece.listing_tags)
        if stuffing_violations.any?
          return needs_human(
            "Description shows possible keyword stuffing: #{stuffing_violations.join('; ')}. " \
            "Per Etsy's guidance, tags should appear naturally, not be forced.",
            { description: result, violations: stuffing_violations }
          )
        end

        # Positioning-claim specificity check — reject "everyone" / "anyone" / "all"
        claim = result["positioning_claim"].to_s.downcase
        if claim.match?(/\b(everyone|anyone|anybody|all(?:\s+kinds\s+of)?)\b/)
          return needs_human(
            "Positioning claim is not specific enough — this Is Marketing's principle rejects " \
            "'for everyone / for anyone'. Positioning was: #{result['positioning_claim'].inspect}. " \
            "Rewrite with a specific 'who is this for' claim.",
            { description: result }
          )
        end

        piece.update!(listing_description: result["full_description"])
        # Still gated by the ownership tag — human confirms tone
        needs_human(
          "Description drafted. Confirm the tone reads on-brand before Step 7. Specific " \
          "positioning claim: #{result['positioning_claim'].inspect}",
          { description: result }
        )
      end

      private

      def default_positioning_target
        rules("positioning").rules.dig("positioning", "positioning_target")
      end

      def parsed_inches(dimensions)
        match = dimensions.to_s.match(/(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)/)
        match && [match[1].to_f, match[2].to_f]
      end

      def trend_evidence
        TrackAResearch.trend_evidence
      end

      def check_keyword_stuffing(text, tags)
        return [] if tags.blank?
        violations = []
        Array(tags).each do |tag|
          count = text.to_s.downcase.scan(/\b#{Regexp.escape(tag.downcase)}\b/).size
          violations << "'#{tag}' appears #{count}× (max 2)" if count > 2
        end
        violations
      end
    end
  end
end
