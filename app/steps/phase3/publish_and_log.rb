module Steps
  module Phase3
    class PublishAndLog < Steps::Base
      step id: "P3_8", mechanism: :lookup, ownership: "[AGENT-ASSISTED]"

      REQUIRED_BEFORE_PUBLISH = %w[
        listing_title listing_tags listing_attributes listing_description listing_category
      ].freeze

      def perform
        # On resume after a manual publish, the human supplies the listing id via context.
        if context[:manual_listing_id].present?
          return finalize(context[:manual_listing_id])
        end

        missing = REQUIRED_BEFORE_PUBLISH.select { |f| piece.send(f).blank? }
        if missing.any?
          return fail_step(
            "Cannot publish — required listing fields blank: #{missing.join(', ')}. " \
            "Steps 3-7 must all complete first.",
            { missing_fields: missing }
          )
        end

        photos = (piece.photos || {}).select { |_, v| v.present? }
        if photos.empty?
          return fail_step("Cannot publish — no photos attached to piece.", {})
        end

        payload = build_payload(photos)
        Workflow::RunMode.require_committed!("Etsy publish")
        result  = Etsy::Adapter.build.create_listing(payload: payload)

        if result.status == "pending_manual"
          return needs_human(
            "ETSY_ADAPTER=manual — payload written to #{result.raw_response[:payload_file]}. " \
            "Publish manually in Etsy Shop Manager, then paste the resulting listing_id into " \
            "context[:manual_listing_id] to complete this step.",
            { payload_file: result.raw_response[:payload_file] }
          )
        end

        finalize(result.listing_id)
      rescue Etsy::ApiError => e
        fail_step("Etsy publish failed: #{e.message}", {})
      end

      private

      def finalize(listing_id)
        piece.update!(
          etsy_listing_id: listing_id,
          published_at: Time.current,
          status: "complete"
        )

        # Create the baseline performance snapshot — module 07 reads these later
        PerformanceSnapshot.create!(
          piece_record: piece,
          captured_on: Date.current,
          views: 0, favorites: 0, orders: 0, revenue: 0,
          raw: { baseline: true, etsy_listing_id: listing_id }
        )

        ok({ etsy_listing_id: listing_id, published_at: piece.published_at })
      end

      def build_payload(photos)
        {
          title: piece.listing_title,
          description: piece.listing_description,
          tags: piece.listing_tags,
          taxonomy_id: piece.listing_category,
          quantity: 1,
          state: "active",
          attributes: piece.listing_attributes,
          photos: photos.values
        }
      end
    end
  end
end
