Draft an Etsy listing title for this piece.

The piece:
- Style: %{style_name}
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
3. **Include occasion/recipient words ONLY** if it's essential to what the item literally is
   (a genuinely occasion-specific product). Do NOT decorate with "gift for wife" or
   "anniversary present" on a piece that isn't occasion-specific.
4. **Exclude:** subjective adjectives ("beautiful", "perfect", "stunning"), price, emoji,
   decorative punctuation, ALL CAPS marketing phrases.

Return JSON matching the required schema. Also return the first 6 words as a separate field
so validation can check the descriptor lead is genuine.
