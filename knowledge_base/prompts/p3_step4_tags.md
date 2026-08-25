Generate 13 tags for this Etsy listing. Etsy provides exactly 13 slots; use all of them.

The piece:
- Style: %{style_name}
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
3. **Balance broad and long-tail.** Roughly 3 broad, 10 specific/long-tail.
4. **No near-duplicates.** "modern wall art" and "modern art wall decor" are duplicative;
   diversify instead.

Return JSON matching the required schema — 13 tags, each labelled with which of the four angles
it serves. If you cannot cover at least 3 of 4 angles, report that gap explicitly; do not pad
with a bad tag to force coverage.
