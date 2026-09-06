module Agents
  # P3_6, P3_8 — customer-facing safety. Phase 2 §6 Limitation 4 requires anything reaching a
  # customer to be fact-checked: a wrong weight rating or hanging-hardware claim is a physical
  # hazard, and under the "here is how to hang it" promise that content is part of the product.
  class CustomerSafetyQa < Base
    agent id: "customer_safety_qa", covers: %w[P3_6 P3_8]

    # Hardware, weight-rating, and conservation terms whose presence in customer-facing copy must
    # be traceable to the rule files before publish.
    WATCHED = %w[hanger sawtooth anchor screw wire hook weight lbs kg
                 conservation uv glass humidity bathroom kitchen].freeze

    def evaluate
      text = customer_facing_text.downcase
      hits = WATCHED.select { |w| text.include?(w) }
      c = [cite("hanging_hardware.rules"), cite("safekeeping.rules")]
      return [pass("No hardware, weight-rating, or conservation claims in customer-facing copy.",
                   c)] if hits.empty?

      [blocking(
        "Customer-facing copy contains hardware/conservation terms (#{hits.join(', ')}). Per " \
        "Phase 2 §6 Limitation 4 these must be fact-checked before publishing — a wrong weight " \
        "rating is a physical hazard.", c, { matched: hits })]
    end

    private

    def customer_facing_text
      d = data
      [d["description"], d["title"], d["listing_description"]].compact.map(&:to_s).join(" ")
    end
  end
end
