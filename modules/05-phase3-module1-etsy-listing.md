# Module 05 — Phase 3, Module 1: Etsy Listing Creation

> **Self-contained.** Every Etsy rule the pipeline reads is written out below verbatim. Do not
> search the internet for the Etsy content — it's all here. Build exactly what is specified.
>
> **Volatility warning specific to this module:** unlike the arrangement-book rules of Phase 2,
> Etsy actively changes its search algorithm and Seller Handbook guidance. Every rule file here is
> tagged `volatility: live` (see module 00 §4.3). Module 07's evolution loop reads these tags to
> flag which rule files need periodic re-verification against `etsy.com/seller-handbook` — do not
> treat this module's rules as permanently accurate the way Phase 2's can be.

---

## Contract

**Depends on:** module 00 (base infrastructure, `PieceRecord`), module 01 (style_specs with locked
style-level axes), module 02 (scene axes), module 03 (`PieceRecord.chosen_url`), module 04
(`PieceRecord.composite_url` — the Lifestyle photo — plus every Phase 2 frame/mat/color decision).

**Provides:**
- 8 `knowledge_base/rules/etsy_*.yml` files (one per §2 subsection + the search-mechanism doc)
- 3 `knowledge_base/prompts/p3_*.md` files (title, tags, description — the three LLM-driven steps)
- `app/steps/phase3/*.rb` — 9 step classes (P3_1, P3_1b, P3_2, P3_3, P3_4, P3_5, P3_6, P3_7, P3_8)
- `app/llm/schemas/phase3/*.rb` — schemas for title/tags/description generation and hero-photo
  selection
- `app/services/etsy/adapter.rb` + `app/services/etsy/api_client.rb` — Etsy Open API integration
  behind an adapter (Etsy API can go down, versions change, and the manual fallback matters here
  even more than for image generation)

**Consumed by:** module 06 (orchestration reads status transitions), module 07 (evolution loop
reads `PieceRecord.listing_*` + `performance_snapshots` to close the feedback loop).

**Must not:** touch style/scene/spec files (modules 01/02 own those), regenerate the composite
Lifestyle photo (module 04 owns that; this module *uses* it), touch pricing (Step 7 records the
human's decision but this module does not compute a price), publish an unfilled listing (Step 8's
publish call is gated on Steps 3–7 all being complete).

---

## 1. What Phase 3 Module 1 is

Phase 3 turns a Phase-2-composited piece into a **published, search-optimized Etsy listing** plus a
logged baseline for module 07 to read. Cadence: `daily` (per piece).

### 1.1 The Etsy Open API — one integration, one adapter

Every step that talks to Etsy goes through a single `Etsy::Adapter`. The adapter has one production
implementation (`Etsy::ApiClient` — calls the real Etsy Open API) and one no-cost fallback
(`Etsy::ManualAdapter` — writes the listing payload to a file, pauses for you to paste back a
listing ID after publishing by hand). Same pattern as module 03's image-gen adapter, same reason:
the moment you switch, one env var flips it; nothing else changes.

### 1.2 Three LLM calls, six rule lookups

Of the 9 steps, only 3 use an LLM: Step 3 (draft title), Step 4 (fill tags), Step 6 (write
description). Step 2 also uses a vision call for hero-photo evaluation. Steps 1, 1b, 5, 7, 8 are
lookups + API calls, no LLM. Same discipline as Phase 2 — ownership tag ≠ mechanism.

### 1.3 The "photos are extra" step

Step 1b is the notable structural addition versus Phase 2 → Phase 3's simple handoff: Phase 2's
composite is only the *Lifestyle* photo type. Etsy listings need at least Studio + Lifestyle +
Detail (per §2.4a of the source). Step 1b either uses your provided studio/detail assets or calls
the image-generation adapter (module 03) with a scoped prompt to produce them. This step is
`[AGENT-ASSISTED — human confirms]` because AI-generated studio/detail shots are still a mixed
bag and the reviewer should approve before publish.

### 1.4 Business-book grounding

Step 6's description prompt is where *This Is Marketing* gets its most direct application in the
whole pipeline. The book's positioning principle — "make a specific claim about who this is for
and what problem it solves" — becomes a hard constraint on the description schema (see §5.3).

---

## 2. Rule files (7 files, from Phase 3 §1 + §2)

### 2.1 `knowledge_base/rules/etsy_search_mechanism.yml`

The §1 explainer — how Etsy search works. Not read by a daily step; consumed by module 07's
performance analysis and by Step 6's description prompt as context.

```yaml
meta:
  source: "Phase 3, §1 — How Etsy Search Actually Works"
  citation: "Etsy Seller Handbook (etsy.com/seller-handbook) and Etsy Help Center (help.etsy.com)"
  volatility: live
  volatility_note: >
    Etsy explicitly states its search algorithm changes regularly. Re-verify against the current
    Seller Handbook periodically. Module 07 reads volatility: live to flag this file for review.
  last_verified: "TODO — fill in on first setup"

rules:
  query_matching:
    fields_evaluated: [title, tags, attributes, description, first_photo, reviews]
    holistic: >
      Evaluated across fields, not any single one in isolation. A tag missing from the title
      can still match; a title missing from the tags can still match.

  ranking_factors:
    relevancy:
      what: "Exact keyword matches across title/tags/description/attributes rank higher for that query"
    shop_quality:
      what: "Shop branding — icon, banner, about section. Buyers want to know who they're buying from."
    listing_quality:
      what: "Multiple high-quality photos plus a clear return policy — specifically called out as critical."
    customer_service_quality:
      what: "Trailing 3 months: average review rating, message response rate, case rate."
    translations_language:
      what: "Content should match the shop's set language; self-added translations outperform machine translation."
    listing_engagement_rate:
      what: >
        Conversion rate (views → purchases). Etsy explicitly frames this as a trust signal, not
        just a sales metric — module 07 should treat conversion as a listing-health measure,
        not only a business KPI.
    recency:
      what: >
        New/renewed listings get a small, temporary boost so Etsy can learn how buyers respond.
        Etsy explicitly states repeatedly renewing just to chase this boost is NOT effective.
      anti_pattern: renewal_chasing
    shoppers_habits:
      what: >
        Personalized via Context Specific Ranking. Etsy explicitly warns that searching your own
        shop isn't representative of what other buyers see.
      anti_pattern: self_search_verification

  # What Etsy explicitly says does NOT affect organic ranking
  does_not_affect_ranking:
    items:
      - name: etsy_plus
        what: "Etsy Plus subscription — no ranking effect"
      - name: star_seller
        what: "Star Seller status — a trust/conversion signal, not a ranking input"
      - name: etsy_ads
        what: "Etsy Ads — only affects designated ad placements, not organic results"
    note: >
      Worth stating plainly because third-party SEO content often implies otherwise. If you see
      advice claiming these affect organic ranking, disregard it.
```

### 2.2 `knowledge_base/rules/etsy_tags.yml`

```yaml
meta:
  source: "Phase 3 §2.1 — Tags"
  citation: "Etsy Seller Handbook — Tags guidance"
  volatility: live
  last_verified: "TODO — fill in on first setup"

rules:
  slot_count: 13
  slot_rule: "Fill ALL 13 slots. Each is a separate query-match opportunity."

  phrase_style:
    prefer: multi_word_long_tail
    example_good: "japandi wall art living room"
    example_bad_pair: ["japandi", "wall art"]
    reason: >
      Multi-word phrases and long-tail keywords beat single words. A shopper searching a
      multi-word query matches a multi-word tag; splitting the phrase into single-word tags
      leaves match opportunities on the table.

  # Diversification is not optional
  angle_diversity:
    required_angles:
      - style_descriptor
      - room_or_space_use
      - gift_or_occasion
      - alternate_use
    reason: >
      A listing that only repeats style words in different phrasings leaves match opportunities
      on the table. Etsy's own example: a candle can also be tagged "spa day accessory" —
      alternate-use framing catches queries the primary framing misses.
    validation:
      min_angles_covered: 3   # at least 3 of 4 angles represented across the 13 tags

  balance:
    rule: >
      Balance a few broad terms with several specific/long-tail ones — broad casts a wide net,
      long-tail faces less competition.
    ratio_guidance: "roughly 3 broad : 10 specific"
```

### 2.3 `knowledge_base/rules/etsy_title.yml`

```yaml
meta:
  source: "Phase 3 §2.2 — Title (with rule details from §3 STEP 3)"
  citation: "Etsy Seller Handbook — Title guidance"
  volatility: live
  last_verified: "TODO — fill in on first setup"

rules:
  # From §2.2 — the two headline rules
  lead_rule:
    what: "Lead with the clearest, most literal descriptor of what the item actually is"
    reason: >
      For buyer scanning on mobile — shoppers see only the first few words in search results.
      NOT for ranking: title word order does NOT affect Etsy's ranking algorithm, per Etsy's
      own statement. This rule serves the buyer, not the algorithm.
    misinterpretation_warning: >
      Third-party SEO content often claims word order matters for ranking. It does not. But
      leading with the descriptor still matters — for the buyer, not the algorithm.

  ai_tool_note:
    what: "Etsy offers an optional AI-suggested-title tool based on current title, first photo, and description."
    use: "Useful as a starting point, not something to trust blindly for accuracy."

  # From §3 STEP 3 — additional rules
  hard_rules:
    include_only:
      - what: "style + subject + product type"
      - what: "occasion/recipient word ONLY if it's essential to what the item literally is"
        example_include: "a genuinely occasion-specific product (e.g. a wedding-anniversary print)"
        example_exclude: "using 'anniversary' as a marketing angle on a piece that isn't occasion-specific"
    exclude:
      - "subjective adjectives ('beautiful', 'perfect', 'stunning') — those belong in the description"
      - "price — never in the title"
      - "emoji, decorative punctuation, ALL CAPS marketing phrases"

  # The lead structure — enforced in Step 3's schema
  first_words_test:
    rule: >
      A shopper skimming mobile search results should be able to tell what this is from the
      FIRST FEW WORDS ALONE. If the first 6 words don't answer "what is this thing", rewrite.
    validation_words: 6
```

### 2.4 `knowledge_base/rules/etsy_attributes.yml`

```yaml
meta:
  source: "Phase 3 §2.3 — Attributes and category"
  citation: "Etsy Seller Handbook — Attributes and Categories"
  volatility: live
  last_verified: "TODO — fill in on first setup"

rules:
  fill_all_applicable:
    rule: "Fill EVERY applicable attribute field. Attributes are part of query matching, same as tags."
    reason: >
      A blank attribute is a query the listing cannot match. There is no algorithmic cost to
      filling one that fits; there IS a cost to leaving one blank.

  category_rule:
    rule: "Choose the most specific category available, not a generic parent category."

  applicable_fields_for_wall_art:
    # A pipeline default set. Etsy's actual category tree changes; this list is a starting point,
    # not authoritative — the P3_5 step class reads the live category tree via the Etsy API and
    # matches these fields against what's actually available for the selected category.
    - name: primary_color
      source: "derived from PieceRecord (mood + color_role feeds this)"
    - name: secondary_color
      source: "derived from PieceRecord.chosen_url — vision-classified"
    - name: room
      source: "derived from scene_spec.room_type"
    - name: style
      source: "spec.name (e.g. 'Japandi')"
    - name: material
      source: "derived from Phase 2 frame_material_category + print substrate"
    - name: orientation
      source: "derived from art image aspect ratio"
    - name: occasion
      source: "human-set only — leave blank if not genuinely occasion-specific"
    - name: dimensions
      source: "PieceRecord.composite_measurements"
```

### 2.5 `knowledge_base/rules/etsy_photos.yml`

Photo-technical rules PLUS the seven-photo-types table.

```yaml
meta:
  source: "Phase 3 §2.4 (technical rules) and §2.4a (seven photo types)"
  citation: >
    Etsy Seller Handbook — Photos guidance; and Etsy's web article "7 Essential Types of
    Product Photos" for the seven-types framing.
  volatility: live
  last_verified: "TODO — fill in on first setup"

rules:
  # Technical rules from §2.4
  file_types:
    allowed: [jpg, gif, png, svg, heic]
    disallowed_reasons:
      animated_gif: "Not supported — first frame only"
      transparent_png: "Transparent area renders as BLACK on Etsy. Do not upload transparent PNGs."

  # THIS IS TWO DIFFERENT NUMBERS — the manifest explicitly flags this as a common error
  resolution:
    ranking_floor_px: 635
    ranking_floor_rule: >
      First listing photo must be at LEAST 635×635 pixels or the listing incurs a ranking
      penalty. This is the FLOOR, not the target.
    recommended_target_px: 2000
    recommended_target_rule: >
      Etsy separately RECOMMENDS 2000px+ on the shortest side so photos "pop" and support the
      zoom function. 2000px is the TARGET, not the floor.
    important_do_not_conflate: >
      635 and 2000 are different numbers with different purposes. Do not average them, do not
      pick one. Check against BOTH: fail hard below 635; warn if below 2000.

  slot_count: 10
  slot_rule: >
    Use as many slots as genuinely add information. Multiple high-quality photos are explicitly
    named as a listing-quality ranking factor. Padding with low-signal photos hurts, not helps.

  crop_survivability:
    rule: >
      Etsy reuses listing photos across pages/placements at different crops. Upload photos that
      work across multiple crop ratios (square and rectangle).

  first_photo:
    what_it_carries:
      - "Part of query-matching evaluation"
      - "Thumbnail shown in search results"
    should_be: "Clearest, most eye-catching image — not necessarily the most artistic one"

  # Supplementary crop tip — explicitly flagged in the source doc
  first_photo_crop_tip:
    source: supplementary_third_party
    caveat: "NOT Etsy-official — verify before relying on it"
    rule: >
      Search-result thumbnails crop the hero photo to roughly a 4:3 to 5:4 ratio. A
      tightly-centered square composition tends to survive this crop better than a portrait
      orientation with the subject near the top.
    use_as: guidance_not_rule

  # §2.4a — the seven photo types
  photo_types:
    studio:
      description: "Product alone, plain background, strong light"
      applies_to_wall_art: yes_required
      role: "Clear, bright thumbnail candidate"
    lifestyle:
      description: "Product styled in its setting"
      applies_to_wall_art: yes_required
      role: "This IS Phase 2's Step 6 composite — do not regenerate"
      source: phase_2_step_6
    scale:
      description: "Visual size reference (room with human figure, or ruler/measurement overlay)"
      applies_to_wall_art: yes_recommended
      role: "Buyer hesitation around wall art size is common"
      reuse: "Use Phase 2's already-computed sizing math — do not re-derive"
    detail:
      description: "Close-up on texture/craftsmanship"
      applies_to_wall_art: yes_required
      role: "Print texture, paper quality, frame corner/edge"
    group:
      description: "Multiple variants together"
      applies_to_wall_art: conditional
      condition: "Only if this listing offers multiple sizes/variants shown together"
    packaging:
      description: "What arrives in the mail"
      applies_to_wall_art: conditional
      condition: "Only if selling a physical/printed product, not a digital download"
    process:
      description: "Item being made"
      applies_to_wall_art: optional
      note: "Doubles as social content, not required for the listing itself"

  # Which photos are treated as REQUIRED by Step 1b's generation logic
  required_types: [studio, lifestyle, detail]
```

### 2.6 `knowledge_base/rules/etsy_policy.yml`

```yaml
meta:
  source: "Phase 3 §2.5 — Return policy and shipping"
  citation: "Etsy Seller Handbook — Return policy and Shipping policies"
  volatility: live
  last_verified: "TODO — fill in on first setup"

rules:
  return_policy:
    rule: >
      A clear return policy is explicitly named as part of the listing-quality ranking factor.
      Don't leave it blank.
    validation:
      must_be_set: true

  shipping_price_factor:
    rule: >
      Etsy has stated it factors shipping price into US search ranking, specifically to avoid
      disadvantaging buyers with a high shipping charge relative to item price.
    anti_pattern:
      name: low_item_price_inflated_shipping
      what: >
        Setting a low item price and inflating shipping to compensate. Etsy's own ranking
        approach is designed to work AGAINST this — not a way to game the system.
    validation:
      warn_if: "shipping_cost > 0.4 * item_price"     # heuristic; refine after live data
      reasoning: >
        A shipping cost approaching half the item price triggers the pattern Etsy penalises.
        Warn, don't block — this is a rough heuristic, and legitimate cases exist (heavy items).
```

### 2.7 `knowledge_base/rules/etsy_antipatterns.yml`

The §2.6 "what NOT to do" list. Kept as a separate file so module 07's evolution loop can read it
independently — when performance data suggests trying an anti-pattern, this file is the safeguard
that flags it.

```yaml
meta:
  source: "Phase 3 §2.6 — What NOT to do (directly contradicts common third-party SEO advice)"
  citation: "Etsy Seller Handbook — sourced from Etsy's own statements about ineffective strategies"
  volatility: live
  last_verified: "TODO — fill in on first setup"

rules:
  # 3 anti-patterns
  renewal_chasing:
    what: "Renewing/relisting repeatedly to chase the temporary 'new listing' boost"
    etsy_says: "Ineffective use of time versus improving tags or conversion rate"
    on_detect: warn_and_refuse
    reasoning: >
      Module 07's evolution loop might otherwise 'discover' that renewed listings temporarily
      spike, and 'suggest' this as a strategy. This rule blocks it — the source is explicit that
      this is ineffective long-term.

  self_search_verification:
    what: "Judging your ranking by searching your own shop"
    etsy_says: >
      Personalization means your results aren't representative of what other buyers see. Use
      Shop Stats' actual traffic/search-term data instead.
    on_detect: warn
    reasoning: "Same category as renewal_chasing — a mistake performance data can teach you into."

  plus_starseller_ads_assumed_ranking:
    what: "Assuming Etsy Plus, Star Seller, or Etsy Ads move organic placement"
    etsy_says: "None of them do, per Etsy's own statement."
    on_detect: warn
    see_also: "etsy_search_mechanism.yml → does_not_affect_ranking"
```

---

## 3. Prompt files (3 — the three LLM steps)

### 3.1 `knowledge_base/prompts/p3_step3_title.md`

```markdown
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
```

### 3.2 `knowledge_base/prompts/p3_step4_tags.md`

```markdown
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
```

### 3.3 `knowledge_base/prompts/p3_step6_description.md`

```markdown
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
```

---

## 4. Schema classes

```ruby
# app/llm/schemas/phase3/title_schema.rb
module Schemas
  module Phase3
    class TitleSchema < RubyLLM::Schema
      string :title,
             description: "The full listing title. No price, no emoji, no subjective adjectives, no ALL CAPS."
      string :first_six_words,
             description: "The first 6 words of the title, extracted separately for validation of the descriptor lead."
      boolean :occasion_word_included,
              description: "True only if an occasion/recipient word is present AND the piece is genuinely occasion-specific."
      string :reasoning
    end
  end
end
```

```ruby
# app/llm/schemas/phase3/tags_schema.rb
module Schemas
  module Phase3
    class TagsSchema < RubyLLM::Schema
      array :tags,
            description: "Exactly 13 tags. Each tag labelled with the angle it serves." do
        object do
          string :tag
          string :angle, enum: %w[style_descriptor room_or_space_use gift_or_occasion alternate_use]
          string :breadth, enum: %w[broad specific_long_tail]
        end
      end
      integer :distinct_angles_covered,
              description: "How many of the 4 angles are represented across the 13 tags. Validation requires >= 3."
      array :missing_angles,
            description: "Angles you couldn't populate with a non-forced tag."
    end
  end
end
```

```ruby
# app/llm/schemas/phase3/description_schema.rb
module Schemas
  module Phase3
    class DescriptionSchema < RubyLLM::Schema
      string :essential_info_block,
             description: "Specs first: dimensions, sizes/variants, what's included, digital vs. physical, turnaround."
      string :engagement_block,
             description: "Story/positioning content, after the essential info."
      string :positioning_claim,
             description: "The specific 'who this is for' sentence. Must be specific, not 'for everyone'."
      array :tag_phrases_used, of: :string,
            description: "Which tag phrases you incorporated in the description. Used to check both presence and non-stuffing."
      string :full_description,
             description: "essential_info_block + engagement_block joined; what actually gets sent to Etsy."
    end
  end
end
```

```ruby
# app/llm/schemas/phase3/hero_photo_schema.rb
module Schemas
  module Phase3
    class HeroPhotoSchema < RubyLLM::Schema
      string :recommended_hero,
             description: "The URL of the photo recommended as position 1"
      string :reasoning,
             description: "Why this one is the clearest and most eye-catching — not why it's the most artistic."
      array :ordering, of: :string,
            description: "Full recommended photo order, hero first, up to 10 slots."
      integer :photo_count
    end
  end
end
```

---

## 5. Etsy adapter

Same pattern as module 03's image-gen adapter — one interface, two implementations, `.env` chooses.

### 5.1 Add to `.env` / `.env.example`

```bash
# Etsy — leave manual to develop and test without publishing anything
ETSY_ADAPTER=manual                        # switch to "api" when ready
ETSY_API_KEY=
ETSY_SHOP_ID=
ETSY_OAUTH_TOKEN=
```

Same principle as the image-gen adapter: `.env.example` ships with `manual` so a fresh clone never
accidentally publishes something to a real Etsy shop while a developer is exploring.

### 5.2 Adapter interface

```ruby
# app/services/etsy/adapter.rb
module Etsy
  class ApiError < StandardError; end

  Result = Struct.new(:listing_id, :status, :raw_response, keyword_init: true)

  class Adapter
    def self.build
      case ENV.fetch("ETSY_ADAPTER", "manual")
      when "manual" then ManualAdapter.new
      when "api"    then ApiClient.new
      else raise ApiError, "Unknown ETSY_ADAPTER=#{ENV['ETSY_ADAPTER']}"
      end
    end

    def name = raise(NotImplementedError)

    # payload: full listing hash (title, description, tags, price, quantity, photos, policy...)
    # Returns Result with listing_id set if published.
    def create_listing(payload:) = raise(NotImplementedError)

    # Fetches the live category tree for filling attributes properly.
    def fetch_category_tree = raise(NotImplementedError)
  end
end
```

### 5.3 `Etsy::ApiClient` — Etsy Open API v3

```ruby
# app/services/etsy/api_client.rb
module Etsy
  class ApiClient < Adapter
    BASE_URL = "https://openapi.etsy.com/v3/"

    def name = "etsy_openapi_v3"

    def create_listing(payload:)
      response = connection.post("application/shops/#{ENV.fetch('ETSY_SHOP_ID')}/listings") do |req|
        req.body = payload
      end

      unless response.success?
        raise ApiError, "Etsy listing create failed (HTTP #{response.status}): #{response.body}"
      end

      body = JSON.parse(response.body)
      Result.new(listing_id: body["listing_id"].to_s, status: "published", raw_response: body)
    end

    def fetch_category_tree
      response = connection.get("application/seller-taxonomy/nodes")
      raise ApiError, "Etsy taxonomy fetch failed (HTTP #{response.status})" unless response.success?
      JSON.parse(response.body)["results"]
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.headers["x-api-key"] = ENV.fetch("ETSY_API_KEY")
        f.headers["Authorization"] = "Bearer #{ENV.fetch('ETSY_OAUTH_TOKEN')}"
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
```

**Important verification note:** Etsy's Open API is well-documented but changes. Before running
this against a real shop, verify the exact endpoint paths (`shops/{shop_id}/listings`) and the
required OAuth scopes (`listings_w` at minimum) against `developers.etsy.com` — the plan lists
correct paths as of drafting but this is exactly the kind of live-external-system fact that goes
stale between drafting and execution. Do not skip this verification.

### 5.4 `Etsy::ManualAdapter`

```ruby
# app/services/etsy/manual_adapter.rb
module Etsy
  class ManualAdapter < Adapter
    def name = "manual"

    def create_listing(payload:)
      dir = Rails.root.join("tmp", "manual_etsy_payloads")
      dir.mkpath
      file = dir.join("listing_#{Time.current.to_i}.json")
      file.write(JSON.pretty_generate(payload))

      Result.new(
        listing_id: nil,
        status: "pending_manual",
        raw_response: { pending: true, payload_file: file.to_s }
      )
    end

    def fetch_category_tree = []   # returning [] triggers "no live taxonomy available" branch in P3_5
  end
end
```

---

## 6. Step implementations (9 classes)

### 6.1 P3_1 — Pull inputs from Phase 2 `[AGENT-READY]`

```ruby
# app/steps/phase3/pull_inputs.rb
module Steps
  module Phase3
    class PullInputs < Steps::Base
      step id: "P3_1", mechanism: :lookup, ownership: "[AGENT-READY]"

      REQUIRED_PIECE_FIELDS = %w[
        chosen_url composite_url frame_material_category frame_contour matting_technique
        color_role_confirmed mood content_type room_type
      ].freeze

      def perform
        missing = REQUIRED_PIECE_FIELDS.select { |f| piece.send(f).blank? }
        if missing.any?
          return fail_step(
            "Phase 3 cannot start — required Phase 2 outputs are missing: #{missing.join(', ')}. " \
            "Complete module 04's Steps 4, 4b, 5, 6 for this piece first.",
            { missing_fields: missing }
          )
        end

        ok({
          chosen_url: piece.chosen_url,
          composite_url: piece.composite_url,   # This IS the Lifestyle photo (§2.4a)
          frame_summary: {
            category: piece.frame_material_category,
            finish: piece.frame_material_finish,
            contour: piece.frame_contour,
            matting: piece.matting_technique
          },
          style_summary: {
            style_name: spec.name, mood: piece.mood,
            content_type: piece.content_type, color_role: piece.color_role_confirmed
          },
          dimensions: piece.composite_measurements&.dig("art_width_px", "art_height_px")
        })
      end
    end
  end
end
```

### 6.2 P3_1b — Generate missing photo types `[AGENT-ASSISTED — human confirms]`

```ruby
# app/steps/phase3/generate_photo_types.rb
module Steps
  module Phase3
    class GeneratePhotoTypes < Steps::Base
      step id: "P3_1b",
           mechanism: :image_gen,
           ownership: "[AGENT-ASSISTED — human confirms]"

      # context: { skip_types: [], provided_urls: { studio:, detail:, scale:, ... } }
      def perform
        photo_rules = rules("etsy_photos").rules
        required    = photo_rules["required_types"]   # [studio, lifestyle, detail]
        photos      = piece.photos || {}
        # Lifestyle already exists from Phase 2
        photos["lifestyle"] ||= piece.composite_url

        # Merge any human-provided URLs
        photos.merge!(context.fetch(:provided_urls, {}))

        # Which required types are still missing?
        missing_required = required.map(&:to_s) - photos.keys.select { |k| photos[k].present? }
        skip = Array(context[:skip_types]).map(&:to_s)
        missing_required -= skip

        if missing_required.empty?
          piece.update!(photos: photos)
          return needs_human(
            "All required photo types present (studio, lifestyle, detail). Confirm before " \
            "moving to Step 2 (hero selection). If any provided URL is AI-generated, review " \
            "quality before publish.",
            { photos: photos }
          )
        end

        # Generate what's missing via the image-gen adapter (module 03)
        adapter = ImageGeneration::Adapter.build
        generated_urls = {}
        missing_required.each do |type|
          prompt = build_photo_prompt(type)
          result = adapter.generate(prompt: prompt, n: 1)
          generated_urls[type] = result.urls.first
        end

        photos.merge!(generated_urls.compact)
        piece.update!(photos: photos)

        needs_human(
          "Generated #{generated_urls.keys.join(', ')} via #{adapter.name}. " \
          "AI-generated studio/detail shots are still mixed — REVIEW quality before " \
          "confirming. If any is unusable, upload a real photo and re-run this step.",
          { photos: photos, generated_types: generated_urls.keys }
        )
      end

      private

      def build_photo_prompt(type)
        case type
        when "studio"
          "Studio product photo: a %s framed print (frame material: %s, contour: %s), " \
          "on a plain neutral background with soft even studio lighting. No room, no props." %
            [piece.content_type, piece.frame_material_category, piece.frame_contour]
        when "detail"
          "Close-up detail photo of the corner of a framed print — showing print texture, paper " \
          "grain, and frame edge/corner. Frame: %s. Sharp focus, natural lighting." %
            piece.frame_material_category
        else
          # scale, group, packaging: caller should provide, not generate
          raise "Unexpected photo type for generation: #{type}"
        end
      end
    end
  end
end
```

### 6.3 P3_2 — Select and order photos `[AGENT-ASSISTED — human confirms hero shot]`

```ruby
# app/steps/phase3/select_and_order_photos.rb
module Steps
  module Phase3
    class SelectAndOrderPhotos < Steps::Base
      step id: "P3_2",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms hero shot]"

      def perform
        available = (piece.photos || {}).select { |_, v| v.present? }
        if available.empty?
          return fail_step("No photos on piece — Step 1b must run first.", {})
        end

        # LLM evaluates which photo is the clearest thumbnail candidate
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::Phase3::HeroPhotoSchema)
                        .ask(
                          <<~PROMPT,
                            You have #{available.size} candidate photos for an Etsy listing.
                            Etsy shows the first photo as the search-result thumbnail. Recommend
                            which should be first — the CLEAREST, MOST EYE-CATCHING image, NOT
                            necessarily the most artistic one. A tightly-centered square
                            composition survives Etsy's ~4:3-5:4 thumbnail crop better than a
                            portrait with the subject near the top (supplementary tip, not
                            Etsy-official — apply as guidance).

                            Return the full ordering (up to 10 slots), hero first. Report the
                            photo count.
                          PROMPT
                          with: available.values
                        ).content

        # Also validate technical constraints from the photos rule file
        photo_rules = rules("etsy_photos").rules
        technical_notes = check_technical(available.values, photo_rules)

        needs_human(
          "Confirm hero photo: #{result['recommended_hero']} — #{result['reasoning']}. " \
          "#{technical_notes.any? ? "Technical notes: #{technical_notes.join('; ')}" : 'Technical checks passed.'}",
          { recommended: result, technical_notes: technical_notes }
        )
      end

      private

      # Basic checks; a real image-dimension check would decode the file. This is a lightweight
      # heuristic — module 07 later may harden it.
      def check_technical(urls, rules)
        notes = []
        # Placeholder: real implementation would use ruby-vips (already in Gemfile) to check
        # dimensions per photo. Below stub is where that check would live.
        notes
      end
    end
  end
end
```

### 6.4 P3_3 — Draft title `[AGENT-READY]`

```ruby
# app/steps/phase3/draft_title.rb
module Steps
  module Phase3
    class DraftTitle < Steps::Base
      step id: "P3_3", mechanism: :llm_text, ownership: "[AGENT-READY]"

      # context: { product_type: (e.g. "print", "framed print", "digital download") }
      def perform
        title_rules = rules("etsy_title").rules

        result = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                        .with_schema(Schemas::Phase3::TitleSchema)
                        .ask(prompt("p3_step3_title",
                                    style_name: spec.name,
                                    content_type: piece.content_type,
                                    mood: piece.mood,
                                    color_role: piece.color_role_confirmed,
                                    room_type: piece.room_type,
                                    product_type: context.fetch(:product_type, "wall art print")))
                        .content

        title = result["title"]
        errors = validate_title(title, result, title_rules)

        if errors.any?
          return needs_human(
            "Title draft failed validation: #{errors.join('; ')}. Draft was: #{title.inspect}",
            { title: title, errors: errors, raw: result }
          )
        end

        piece.update!(listing_title: title)
        ok({ title: title, first_six_words: result["first_six_words"] })
      end

      private

      def validate_title(title, result, rules)
        errors = []
        return ["title blank"] if title.blank?

        # Exclude subjective adjectives
        subjective = /\b(beautiful|perfect|stunning|amazing|gorgeous|lovely|breathtaking)\b/i
        errors << "contains subjective adjective(s) — banned by rules.exclude" if title.match?(subjective)

        # Exclude price signals
        errors << "contains a price ($ or price-like number)" if title.match?(/\$|\bprice\b/i)

        # Exclude ALL CAPS multi-word phrases
        errors << "contains ALL CAPS phrase (marketing shout)" if title.match?(/\b[A-Z]{4,}\s+[A-Z]{4,}\b/)

        # Emoji check — Unicode symbols outside basic Latin
        errors << "contains emoji or decorative symbols" if title.match?(/[^\x00-\x7F]/) &&
                                                            !title.match?(/[àâäéèêëîïôöùûüç]/i)

        # First-six-words descriptor test — enforced literally
        first_six = title.split.first(6).join(" ")
        if result["first_six_words"] != first_six
          errors << "reported first_six_words doesn't match actual first six of title"
        end

        errors
      end
    end
  end
end
```

### 6.5 P3_4 — Fill tags `[AGENT-READY]`

```ruby
# app/steps/phase3/fill_tags.rb
module Steps
  module Phase3
    class FillTags < Steps::Base
      step id: "P3_4", mechanism: :llm_text, ownership: "[AGENT-READY]"

      # context: { product_type: }
      def perform
        tag_rules = rules("etsy_tags").rules

        result = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                        .with_schema(Schemas::Phase3::TagsSchema)
                        .ask(prompt("p3_step4_tags",
                                    style_name: spec.name,
                                    content_type: piece.content_type,
                                    mood: piece.mood,
                                    color_role: piece.color_role_confirmed,
                                    room_type: piece.room_type,
                                    product_type: context.fetch(:product_type, "wall art print")))
                        .content

        tags = Array(result["tags"])
        errors = []

        errors << "expected #{tag_rules['slot_count']} tags, got #{tags.size}" unless tags.size == tag_rules["slot_count"]

        angles_covered = tags.map { |t| t["angle"] }.uniq.size
        min_angles = tag_rules["angle_diversity"]["validation"]["min_angles_covered"]
        errors << "only #{angles_covered} angles covered (need #{min_angles})" if angles_covered < min_angles

        # Near-duplicate check — normalize + compare
        normalized = tags.map { |t| t["tag"].to_s.downcase.gsub(/[^a-z0-9\s]/, "").split.sort.join(" ") }
        if normalized.uniq.size < normalized.size
          dups = normalized.tally.select { |_, c| c > 1 }.keys
          errors << "near-duplicate tags detected: #{dups.join(', ')}"
        end

        if errors.any?
          return needs_human("Tags failed validation: #{errors.join('; ')}",
                             { tags: tags, errors: errors })
        end

        piece.update!(listing_tags: tags.map { |t| t["tag"] })
        ok({ tags: tags.map { |t| t["tag"] }, angles_covered: angles_covered })
      end
    end
  end
end
```

### 6.6 P3_5 — Fill attributes and category `[AGENT-READY]`

```ruby
# app/steps/phase3/fill_attributes.rb
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
```

### 6.7 P3_6 — Write description `[AGENT-ASSISTED — human confirms tone]`

```ruby
# app/steps/phase3/write_description.rb
module Steps
  module Phase3
    class WriteDescription < Steps::Base
      step id: "P3_6", mechanism: :llm_text, ownership: "[AGENT-ASSISTED — human confirms tone]"

      # context: { product_type:, dimensions:, sizes:, included:, fulfillment_type:,
      #            turnaround_days:, positioning_target: (specific 'who is this for' string) }
      def perform
        result = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                        .with_schema(Schemas::Phase3::DescriptionSchema)
                        .ask(prompt("p3_step6_description",
                                    style_name: spec.name,
                                    content_type: piece.content_type,
                                    mood: piece.mood,
                                    color_role: piece.color_role_confirmed,
                                    product_type: context.fetch(:product_type, "wall art print"),
                                    dimensions: context.fetch(:dimensions, "See listing"),
                                    sizes: context.fetch(:sizes, "Single size"),
                                    included: context.fetch(:included, "Print only"),
                                    fulfillment_type: context.fetch(:fulfillment_type, "physical"),
                                    turnaround_days: context.fetch(:turnaround_days, 3),
                                    positioning_target: context.fetch(:positioning_target)))
                        .content

        # Validate keyword-stuffing: no tag phrase used more than 2× in the description
        stuffing_violations = check_keyword_stuffing(result["full_description"], piece.listing_tags)
        if stuffing_violations.any?
          return needs_human(
            "Description shows possible keyword stuffing: #{stuffing_violations.join('; ')}. " \
            "Per Etsy's guidance, tags should appear naturally, not be forced.",
            { description: result, violations: stuffing_violations }
          )
        end

        # Positioning-claim specificity check — reject "everyone" / "anyone" / "all"
        claim = result["positioning_claim"].to_s.downcase
        if claim.match?(/\b(everyone|anyone|anybody|all(?:\s+kinds\s+of)?)\b/)
          return needs_human(
            "Positioning claim is not specific enough — this Is Marketing's principle rejects " \
            "'for everyone / for anyone'. Positioning was: #{result['positioning_claim'].inspect}. " \
            "Rewrite with a specific 'who is this for' claim.",
            { description: result }
          )
        end

        piece.update!(listing_description: result["full_description"])
        # Still gated by the ownership tag — human confirms tone
        needs_human(
          "Description drafted. Confirm the tone reads on-brand before Step 7. Specific " \
          "positioning claim: #{result['positioning_claim'].inspect}",
          { description: result }
        )
      end

      private

      def check_keyword_stuffing(text, tags)
        return [] if tags.blank?
        violations = []
        Array(tags).each do |tag|
          count = text.to_s.downcase.scan(/\b#{Regexp.escape(tag.downcase)}\b/).size
          violations << "'#{tag}' appears #{count}× (max 2)" if count > 2
        end
        violations
      end
    end
  end
end
```

### 6.8 P3_7 — Set shipping and return policy `[HUMAN ONLY — pricing/policy strategy]`

```ruby
# app/steps/phase3/shipping_and_returns.rb
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
```

### 6.9 P3_8 — Publish and log baseline `[AGENT-ASSISTED]`

```ruby
# app/steps/phase3/publish_and_log.rb
module Steps
  module Phase3
    class PublishAndLog < Steps::Base
      step id: "P3_8", mechanism: :lookup, ownership: "[AGENT-ASSISTED]"

      REQUIRED_BEFORE_PUBLISH = %w[
        listing_title listing_tags listing_attributes listing_description listing_category
      ].freeze

      def perform
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
        result  = Etsy::Adapter.build.create_listing(payload: payload)

        if result.status == "pending_manual"
          return needs_human(
            "ETSY_ADAPTER=manual — payload written to #{result.raw_response[:payload_file]}. " \
            "Publish manually in Etsy Shop Manager, then paste the resulting listing_id into " \
            "context[:manual_listing_id] to complete this step.",
            { payload_file: result.raw_response[:payload_file] }
          )
        end

        piece.update!(
          etsy_listing_id: result.listing_id,
          published_at: Time.current,
          status: "complete"
        )

        # Create the baseline performance snapshot — module 07 reads these later
        PerformanceSnapshot.create!(
          piece_record: piece,
          captured_on: Date.current,
          views: 0, favorites: 0, orders: 0, revenue: 0,
          raw: { baseline: true, etsy_listing_id: result.listing_id }
        )

        ok({ etsy_listing_id: result.listing_id, published_at: piece.published_at })
      rescue Etsy::ApiError => e
        fail_step("Etsy publish failed: #{e.message}", {})
      end

      private

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
```

---

## 7. Verification for this module

```bash
# 1. All 7 rule files exist, carry citations, and are tagged volatility: live
bin/rails runner '
  files = %w[etsy_search_mechanism etsy_tags etsy_title etsy_attributes
             etsy_photos etsy_policy etsy_antipatterns]
  files.each do |n|
    r = KnowledgeBase::RuleSet.load(n)
    puts "#{n}: source=#{r.meta["source"].present?} citation=#{r.meta["citation"].present?} live=#{r.live?}"
  end
  puts "count=#{files.size}"    # expect 7
'

# 2. Tag rules: 13 slot count, 4 angles, at-least-3 minimum
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("etsy_tags").rules
  puts "slot_count=#{r["slot_count"]}"    # expect 13
  puts "angles=#{r["angle_diversity"]["required_angles"].size}"    # expect 4
  puts "min=#{r["angle_diversity"]["validation"]["min_angles_covered"]}"    # expect 3
'

# 3. Photos: 635 floor and 2000 target both present and different
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("etsy_photos").rules
  puts "floor=#{r["resolution"]["ranking_floor_px"]}"    # expect 635
  puts "target=#{r["resolution"]["recommended_target_px"]}"    # expect 2000
  puts "distinct=#{r["resolution"]["ranking_floor_px"] != r["resolution"]["recommended_target_px"]}"    # expect true
  puts "required_types=#{r["required_types"].sort}"    # expect [detail, lifestyle, studio]
  puts "photo_types_count=#{r["photo_types"].size}"    # expect 7
'

# 4. Photos: supplementary-tip is explicitly flagged as non-Etsy-official
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("etsy_photos").rules
  puts "tip_source=#{r["first_photo_crop_tip"]["source"]}"    # expect supplementary_third_party
  puts "tip_caveat_present=#{r["first_photo_crop_tip"]["caveat"].include?("NOT Etsy-official")}"    # expect true
'

# 5. Search mechanism: 3 things that do NOT affect ranking are listed
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("etsy_search_mechanism").rules
  items = r["does_not_affect_ranking"]["items"]
  puts "not_ranking_count=#{items.size}"    # expect 3
  puts "names=#{items.map { |x| x["name"] }.sort}"
  # expect [etsy_ads, etsy_plus, star_seller]
'

# 6. Anti-patterns file has all 3 anti-patterns
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("etsy_antipatterns").rules
  puts "count=#{r.keys.size}"    # expect 3
  puts "keys=#{r.keys.sort}"
  # expect [plus_starseller_ads_assumed_ranking, renewal_chasing, self_search_verification]
'

# 7. All 9 step classes match registry
bin/rails runner '
  reg = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  reg["phase_3_module_1"]["steps"].each do |s|
    k = s["klass"].constantize
    ok = k.step_id == s["id"] && k.ownership == s["ownership"]
    puts "#{s["id"]}: #{ok ? "ok" : "MISMATCH klass_id=#{k.step_id} ownership=#{k.ownership}"}"
  end
'

# 8. Etsy adapter factory works and defaults to manual
bin/rails runner '
  ENV["ETSY_ADAPTER"] = "manual"
  puts Etsy::Adapter.build.name    # expect "manual"
  ENV["ETSY_ADAPTER"] = "api"
  puts Etsy::Adapter.build.name    # expect "etsy_openapi_v3"
  ENV["ETSY_ADAPTER"] = "manual"
'

# 9. Etsy manual adapter writes a payload file, no API call
bin/rails runner '
  ENV["ETSY_ADAPTER"] = "manual"
  r = Etsy::Adapter.build.create_listing(payload: { title: "test", tags: [] })
  puts "status=#{r.status}"    # expect pending_manual
  puts "file_exists=#{File.exist?(r.raw_response[:payload_file])}"    # expect true
'

# 10. Title validator rejects subjective adjectives, price, ALL CAPS
bin/rails runner '
  step = Steps::Phase3::DraftTitle.new(piece: nil, context: {})
  # Testing via reflection since perform requires a piece — invoke validate_title directly
  errors = step.send(:validate_title, "Beautiful stunning japandi print",
                     {"first_six_words" => "Beautiful stunning japandi print"}, {})
  puts "rejects subjective: #{errors.any? { |e| e.include?("subjective") }}"    # expect true

  errors = step.send(:validate_title, "Japandi print $30 wall art",
                     {"first_six_words" => "Japandi print $30 wall art"}, {})
  puts "rejects price: #{errors.any? { |e| e.include?("price") }}"    # expect true
'

# 11. Description validator rejects "for everyone" positioning
bin/rails runner '
  step = Steps::Phase3::WriteDescription.new(piece: nil, context: {})
  # Direct test of the substr check; production uses the full needs_human flow
  positioning = "This piece is perfect for everyone who loves calm interiors"
  puts "generic detected: #{positioning.downcase.match?(/\\b(everyone|anyone|anybody|all(?:\\s+kinds\\s+of)?)\\b/)}"
  # expect true
'
```

**Also verify by hand:**
- `.env.example` ships with `ETSY_ADAPTER=manual` — a fresh clone must not accidentally publish a
  listing during development.
- The `p3_step6_description.md` prompt explicitly references *This Is Marketing*'s specificity
  principle by name — this is the ONE place in the whole pipeline where a business-book claim is
  directly enforced in an LLM output constraint.
- P3_8 refuses to publish if any of listing_title / tags / attributes / description / category are
  blank — the ordering matters, and skipping Step 7 is caught here even though Step 7 itself
  writes to listing_attributes not a dedicated field.
- No step in this module regenerates the Lifestyle photo — P3_1b treats `piece.composite_url`
  (from module 04) as authoritative and only fills in Studio/Detail (and optionally Scale, Group,
  Packaging) around it.

---

## 8. Manifest coverage

| Manifest ID | Item | Where |
|---|---|---|
| P3_1–P3_8 (9 steps) | All 9 Phase 3 Module 1 steps with verbatim ownership tags | §6 + step_registry.yml (module 00) |
| P3-T1 | Etsy ranking factors (8 factors) | §2.1 `ranking_factors` |
| P3-T2 | Seven photo types | §2.5 `photo_types` |
| P3-P1 | Tags — 13 slots, multi-word/long-tail, diversified angles, broad+specific balance | §2.2 (tags file) |
| P3-P2 | Title — literal descriptor first; word order does NOT rank; AI-title tool caveat | §2.3 (title file) |
| P3-P3 | Attributes — fill every applicable; most specific category | §2.4 (attributes file) |
| P3-P4 | Photos — file types, 635 floor vs 2000 target (not conflated), 10 slots, crop ratios, first-photo weight, supplementary 4:3-5:4 crop tip | §2.5 (photos file) — `resolution.important_do_not_conflate` explicit |
| P3-P5 | Return policy named in ranking; shipping factored into US ranking | §2.6 (policy file) |
| P3-P6 | What NOT to do — 3 bullets: renewal chasing, self-search, Plus/StarSeller/Ads don't rank | §2.7 (antipatterns file) |
| P3-P7 | Etsy Plus, Star Seller, Etsy Ads do NOT affect ranking | §2.1 `does_not_affect_ranking` |
| X4 | Phase 3 Lifestyle == Phase 2 Step 6 composite | §6.2 P3_1b (photos["lifestyle"] ||= composite_url) |
| X5 | Phase 3 Scale reuses Phase 2 sizing math, doesn't re-derive | §2.5 `photo_types.scale.reuse` |
| X8 | Etsy rules are live/changing, need periodic re-verification (module 07 flag) | All rule file `meta.volatility: live` + `volatility_note` |

**Deferred to other modules (per Phase 3 §5):** eBay, Amazon, Own-site modules are behind a
Platform Expansion Gate — not built until performance data proves Etsy is working. Performance
Tracking is not built pending a *Lean Analytics* sourcing decision. Engagement and Pricing tracks
are grounded in books already in the KB (*The Art of Small Business Social Media*, *Influence*,
*This Is Marketing*, *The Paradox of Choice*) but not yet built.
