module Steps
  module Phase3
    class FillAttributes < Steps::Base
      step id: "P3_5", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { category_id: (optional), attributes_overrides: {} }
      def perform
        adapter = Etsy::Adapter.build
        live_tree = adapter.fetch_category_tree

        # Category selection: use human-supplied category_id when given, otherwise leave as nil
        # and require the human to pick — automatic category picking from a live taxonomy is
        # error-prone, and Etsy's category assignment is not casually reversible.
        category_id = context[:category_id]
        if category_id.blank?
          return needs_human(
            "Pick the most specific Etsy category for this listing. Live taxonomy fetched: " \
            "#{live_tree.size} nodes available. Provide category_id in context to continue.",
            { taxonomy_sample: live_tree.first(10) }
          )
        end

        # Derive attributes from spec + piece + composite measurements
        attrs = derive_attributes.merge(context.fetch(:attributes_overrides, {}))

        piece.update!(
          listing_category: category_id,
          listing_attributes: attrs
        )

        ok({ category_id: category_id, attributes: attrs })
      end

      private

      def derive_attributes
        dims = piece.composite_measurements || {}
        art_w = dims["art_width_px"].to_i
        art_h = dims["art_height_px"].to_i
        {
          primary_color: piece.color_role_confirmed,
          room: piece.room_type,
          style: spec.name,
          material: piece.frame_material_category,
          orientation: art_w > art_h ? "landscape" : (art_h > art_w ? "portrait" : "square"),
          dimensions_px: "#{art_w}x#{art_h}",
          mood: piece.mood
        }
      end
    end
  end
end
