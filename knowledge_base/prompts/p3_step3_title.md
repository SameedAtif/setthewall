Draft an Etsy listing title for this piece.

The piece:
- Style: %{style_name}
- Demand terms (what shoppers actually search for, sourced from A0 research): %{demand_terms}
- Subject/content type: %{content_type}
- Mood: %{mood}
- Color role: %{color_role}
- Room the scene is: %{room_type}
- Product type: %{product_type}

Follow Etsy's actual rules for titles (per etsy.com/seller-handbook):

1. **Lead with the clearest, most literal descriptor** — style + subject + product type. A
   shopper skimming mobile search results should be able to tell what this is from the FIRST
   6 WORDS ALONE.
2. **Word order does NOT affect Etsy's ranking algorithm**, per Etsy's own statement.
   Third-party advice often claims otherwise; ignore that. Lead with the descriptor for the
   BUYER'S sake, not the algorithm's.
3. **Mine the demand terms for vocabulary**, but do NOT copy them verbatim: strip any price
   band, size range, or format label ("physical", "digital download") — those are A0 research
   labels, not title words. The demand terms tell you which subject/style keywords shoppers use;
   fold the actual keywords into the descriptor.
4. **Include occasion/recipient words ONLY** if it's essential to what the item literally is
   (a genuinely occasion-specific product). Do NOT decorate with "gift for wife" or
   "anniversary present" on a piece that isn't occasion-specific.
5. **Exclude:** subjective adjectives ("beautiful", "perfect", "stunning"), price, emoji,
   decorative punctuation, ALL CAPS marketing phrases.

Return JSON matching the required schema. Also return the first 6 words as a separate field
so validation can check the descriptor lead is genuine.
