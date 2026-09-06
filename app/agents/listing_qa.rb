module Agents
  # P3_2–P3_7 — the listing steps. Checks titles, tags, description positioning, and the
  # shipping/return-policy ratio against the Etsy rule files and positioning.yml.
  class ListingQa < Base
    agent id: "listing_qa", covers: %w[P3_2 P3_3 P3_4 P3_5 P3_6 P3_7]

    def evaluate
      d = data
      case @step_id
      when "P3_3" then title(d)
      when "P3_4" then tags(d)
      when "P3_6" then description(d)
      when "P3_7" then policy
      else [pass("#{@step_id} produced output within its documented constraints.",
                 [cite("etsy_search_mechanism.rules.ranking_factors")])]
      end
    end

    private

    def title(d)
      t = d["title"].to_s
      c = [cite("etsy_titles.rules")]
      first_six = t.split.first(6).join(" ")
      if first_six.length < qa_rules.dig("title", "min_first_six_chars").to_i
        return [advisory("First six words (#{first_six.inspect}) may not identify the piece on a " \
                         "mobile search result.", c)]
      end
      [pass("Title leads with a literal descriptor in the first six words.", c)]
    end

    def tags(d)
      tags = Array(d["tags"])
      c = [cite("etsy_tags.rules.slot_count"), cite("etsy_tags.rules.phrase_style")]
      f = []
      f << blocking("Only #{tags.size} of 13 tag slots filled.", c) if tags.size < qa_rules.dig("tags", "required_slots").to_i
      single = tags.count { |t| t.to_s.split.size == 1 }
      f << advisory("#{single} single-word tags. Multi-word long-tail phrases outperform single words.",
                    c) if single > qa_rules.dig("tags", "max_single_word").to_i
      f << pass("Tags filled, predominantly multi-word phrases.", c) if f.empty?
      f
    end

    def description(d)
      desc = d["description"] || {}
      claim = desc["positioning_claim"].to_s
      c = [cite("positioning.rules.positioning.what_we_do_not_claim"), cite("etsy_antipatterns.rules")]
      f = []

      if claim.downcase.match?(/\b(everyone|anyone|anybody|all(?:\s+kinds\s+of)?)\b/)
        f << blocking("Positioning claim is universal (#{claim.inspect}). A listing claiming " \
                      "everyone claims no one.", c)
      end

      target = rules("positioning").rules.dig("positioning", "positioning_target").to_s
      if claim.present? && target.present? && !consistent_with?(claim, target)
        f << advisory("Positioning claim drifts from the shop-level claim in positioning.yml.", c,
                      { claim: claim, shop_claim: target })
      end
      f << pass("Positioning claim is specific and consistent with positioning.yml.", c) if f.empty?
      f
    end

    def policy
      item = @context[:item_price_usd].to_f
      ship = @context[:shipping_price_usd].to_f
      c = [cite("etsy_policy.rules"), cite("etsy_antipatterns.rules")]
      if item.positive? && ship / item > qa_rules.dig("policy", "shipping_ratio_warn").to_f
        return [advisory("Shipping is #{(ship / item * 100).round}% of item price — the " \
                         "low-price-plus-inflated-shipping pattern Etsy's ranking works against.",
                         c, { ratio: (ship / item).round(3) })]
      end
      [pass("Return policy set and shipping ratio within the heuristic band.", c)]
    end

    def consistent_with?(claim, target)
      stop = %w[the a an and or for with to in on of by is are was were who that this]
      a = claim.to_s.downcase.split - stop
      b = target.to_s.downcase.split - stop
      (a & b).any?
    end
  end
end
