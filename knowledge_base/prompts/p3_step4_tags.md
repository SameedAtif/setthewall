Generate 13 tags for this Etsy listing. Etsy provides exactly 13 slots; use all of them.

The piece:
- Style: %{style_name}
- Demand terms (what shoppers actually search for, sourced from A0 research): %{demand_terms}
- Content type: %{content_type}
- Mood: %{mood}
- Color role: %{color_role}
- Room the scene is: %{room_type}
- Product type: %{product_type}

Rules from Etsy's own guidance:

1. **Multi-word / long-tail phrases beat single words.** Prefer "japandi wall art living room"
   over "japandi" and "wall art" as separate tags. Each tag is a separate query-match
   opportunity; a multi-word tag catches a multi-word query.
2. **Diversify across FOUR angles** — not all 13 should be style descriptors:
   - style_descriptor (e.g. "japandi print", "minimalist line art")
   - room_or_space_use (e.g. "living room wall art", "bedroom decor")
   - gift_or_occasion (e.g. "housewarming gift", "new home present")
   - alternate_use (e.g. "office print", "studio wall decor" — catching queries the primary
     framing misses; Etsy's own example is a candle also being a "spa day accessory")
3. **Balance broad and long-tail.** At most 4 broad tags; the remaining 9+ must be
   specific/long-tail.
4. **Embed the style descriptor in room/gift/alternate tags.** A tag that is purely generic
   ("living room wall art", "housewarming gift") misses the style entirely. Fold the style in:
   "whimsigoth living room wall art", "whimsigoth housewarming gift". The style descriptor
   (%{style_name} and its close variants) should recur across the tags, not just in the
   style_descriptor angle.
5. **Mine the demand terms for vocabulary** — they are the search phrases shoppers actually use.
   Work their keywords into the tags, but strip price bands, size ranges, and format labels
   ("physical", "digital download"); those are A0 research labels, not tags.
6. **No near-duplicates.** "modern wall art" and "modern art wall decor" are duplicative;
   diversify instead.

Return JSON matching the required schema — 13 tags, each labelled with which of the four angles
it serves. If you cannot cover at least 3 of 4 angles, report that gap explicitly; do not pad
with a bad tag to force coverage.
