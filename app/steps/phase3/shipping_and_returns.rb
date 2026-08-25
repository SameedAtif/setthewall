module Steps
  module Phase3
    class ShippingAndReturns < Steps::Base
      step id: "P3_7", mechanism: :human, ownership: "[HUMAN ONLY — pricing/policy strategy]"

      # context: { return_policy:, shipping_price_usd:, item_price_usd:, confirmed: }
      def perform
        policy_rules = rules("etsy_policy").rules
        antipatterns = rules("etsy_antipatterns").rules

        unless context[:confirmed]
          return needs_human(
            "Set return policy and shipping. Return policy required (listing-quality factor). " \
            "Warn: shipping_price / item_price > 0.4 approaches the 'low item price + inflated " \
            "shipping' anti-pattern Etsy penalises (§2.5).",
            { policy_rules: policy_rules, antipatterns: antipatterns.slice("plus_starseller_ads_assumed_ranking") }
          )
        end

        return_policy = context.fetch(:return_policy)
        shipping = context.fetch(:shipping_price_usd).to_f
        item     = context.fetch(:item_price_usd).to_f

        warnings = []
        if item > 0 && (shipping / item) > 0.4
          warnings << "shipping (#{shipping}) is #{((shipping/item)*100).round}% of item price (#{item}) — approaches Etsy's low-item-price/inflated-shipping anti-pattern"
        end

        piece.update!(
          listing_attributes: (piece.listing_attributes || {}).merge(
            return_policy: return_policy,
            shipping_price_usd: shipping,
            item_price_usd: item
          )
        )

        ok({ return_policy: return_policy, shipping: shipping, item: item, warnings: warnings })
      end
    end
  end
end
