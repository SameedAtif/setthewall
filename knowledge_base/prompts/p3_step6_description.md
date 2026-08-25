Write an Etsy listing description for this piece.

The piece:
- Style: %{style_name}
- Content type: %{content_type}
- Mood: %{mood}
- Color role: %{color_role}
- Product type: %{product_type}
- Dimensions: %{dimensions}
- Available sizes/variants: %{sizes}
- Included in purchase: %{included}
- Digital or physical: %{fulfillment_type}
- Turnaround: %{turnaround_days} days
- Style spec's positioning target ("who is this for"): %{positioning_target}

Structure per Etsy's own guidance:

1. **Essential information FIRST.** Dimensions, available sizes/colors/variants, what's
   included, digital vs. physical, ordering/turnaround. Readable without scrolling past
   marketing copy.
2. **Engaging/story content SECOND.** Not long-form brand storytelling up front.
3. **Work in the listing's tags naturally** — no keyword stuffing. If a tag phrase appears
   twice in a natural sentence, that's fine; if it appears seven times in six sentences, it
   reads as spam.
4. **Make a specific "who this is for" claim.** Per *This Is Marketing* — specific beats
   generic. "For someone building a calm, uncluttered space where a single piece can breathe"
   beats "for everyone who loves art." Vague positioning targets everyone and reaches no one.

Return JSON matching the required schema, with:
- `essential_info_block` — the specs-first section
- `engagement_block` — the story/positioning section
- `positioning_claim` — the specific "who is this for" sentence, quoted from your description
- `tag_phrases_used` — which tag phrases you incorporated, so validation can check for both
  presence and non-stuffing.
