# Phase 3, Module 1: Etsy Listing Creation

**Purpose:** take Phase 2's finished, composited piece and turn it into a published, search-optimized Etsy listing. Output = a live listing plus a logged baseline for the (not-yet-built) Performance Tracking module.

**Sources:** all Etsy-mechanics claims below are sourced from Etsy's own official Seller Handbook (`etsy.com/seller-handbook`) and Etsy Help Center (`help.etsy.com`) — primary source, not third-party SEO content. A small number of supplementary practical tips are drawn from third-party sources and are explicitly flagged as such, with a note to verify rather than trust blindly. Business-strategy claims (description tone, positioning) draw on the four business books already grounding Phase 1/2.

**Scope:** this is Module 1 of Phase 3 (of a "start on one platform, expand once proven" rollout). eBay, Amazon, and Own-site are deferred behind a Platform Expansion Gate — see the scope note at the end.

---

## 1. How Etsy Search Actually Works

Not a step — this is the mechanism the rule tables and steps below are built on. Etsy search has two phases:

**Query matching:** a buyer's search is matched against a listing's title, tags, attributes, description, first photo, and reviews — evaluated holistically, not any single field in isolation.

**Ranking:** matched listings are then ranked by:
| Factor | What it means |
|---|---|
| Relevancy | Exact keyword matches across title/tags/description/attributes rank higher for that query |
| Shop quality | Shop branding (icon, banner, about section) — buyers want to know who they're buying from |
| Listing quality | Multiple high-quality photos + a clear return policy, specifically called out as critical |
| Customer service quality | Average review rating, message response rate, case rate — trailing 3 months |
| Translations/language | Listing content should match the shop's set language; self-added translations outperform machine translation |
| Listing engagement rate | Conversion rate (views → purchases) — Etsy explicitly frames this as a trust signal, not just a sales metric |
| Recency | New/renewed listings get a small, temporary boost so Etsy can learn how buyers respond — Etsy explicitly states repeatedly renewing just to chase this boost is *not* an effective strategy |
| Shoppers' habits | Results are personalized via Context Specific Ranking — Etsy explicitly warns that searching your own shop isn't representative of what other buyers see |

**What Etsy explicitly states does *not* affect organic ranking:** Etsy Plus subscription, Star Seller status (a trust/conversion signal, not a ranking input), and running Etsy Ads (only affects the designated ad placements, not organic results). Worth stating plainly since third-party SEO content often implies otherwise.

---

## 2. Rule Tables

### 2.1 Tags
- Fill all 13 tag slots — each is a separate opportunity to match a query.
- Use multi-word phrases and long-tail keywords over single words (e.g. "japandi wall art living room," not "japandi" and "wall art" as separate tags).
- Diversify tags across angles: style descriptors, room/space use, gift/occasion framing, and alternate-use framing (Etsy's own guidance uses the example of a candle also being a "spa day accessory") — a listing that only repeats style words in different phrasings is leaving match opportunities on the table.
- Balance a few broad terms with several specific/long-tail ones — broad terms cast a wide net, long-tail terms face less competition.

### 2.2 Title
- Lead with the clearest, most literal descriptor of what the item actually is — this matters for buyer scanning on mobile, not for ranking (tag/title *word order* does not affect Etsy's ranking algorithm, per Etsy's own statement).
- Etsy offers an optional AI-suggested-title tool (based on current title, first photo, and description) — useful as a starting point, not something to trust blindly for accuracy.

### 2.3 Attributes and category
- Fill every applicable attribute field (material, primary/secondary color, room, occasion, dimensions, etc.) — attributes are part of query matching, same as tags.
- Choose the most specific category available, not a generic parent category.

### 2.4 Photos
- File types: `.jpg`, `.gif`, `.png`, `.svg`, `.heic` only. Animated GIFs and transparent PNGs are not supported — a transparent PNG will render with the transparent area shown as black.
- **Resolution — two different thresholds, don't conflate them:** first listing photo needs a minimum of 635×635px to avoid a ranking penalty; Etsy separately *recommends* 2000px+ on the shortest side so photos "pop" and support the zoom function. 635px is the floor, 2000px is the target — not the same number.
- Up to 10 photo slots — use as many as genuinely add information; multiple high-quality photos are explicitly named as a listing-quality ranking factor.
- Upload photos that work across multiple crop ratios (square and rectangle) — Etsy reuses listing photos across different pages/placements at different crops.
- The first photo carries extra weight — it's both part of the query-matching evaluation and the thumbnail shown in search results; it should be the clearest, most eye-catching image, not necessarily the most artistic one.
- **Supplementary, third-party, not Etsy-official — verify before relying on it:** search-result thumbnails crop the hero photo to roughly a 4:3–5:4 ratio; a tightly-centered square composition tends to survive this crop better than a portrait orientation with the subject near the top.

### 2.4a The seven photo types (p. n/a — web article, "7 Essential Types of Product Photos")
Etsy's own framing: each type communicates different information, and a well-rounded listing mixes several. For wall art specifically:

| Type | What it is | Applies here? |
|---|---|---|
| **Studio** | Product alone, plain background, strong light | Yes — recommended as the clear, bright thumbnail candidate |
| **Lifestyle** | Product styled in its setting | Yes — this is Phase 2's Step 6 composite |
| **Scale** | Visual size reference | Yes — buyer hesitation around wall art size is common; reuse Phase 2's sizing math |
| **Detail** | Close-up on texture/craftsmanship | Yes — print texture, paper quality, frame corner/edge |
| **Group** | Multiple variants together | Conditional — only if this listing offers multiple sizes/color variants shown together |
| **Packaging** | What arrives in the mail | Conditional — only if selling a physical/printed product, not a digital download |
| **Process** | Item being made | Optional — doubles as social content, not required for the listing itself |

### 2.5 Return policy and shipping
- A clear return policy is explicitly named as part of the listing-quality ranking factor — don't leave it blank.
- Etsy has stated it factors shipping price into US search ranking, specifically to avoid disadvantaging buyers with a high shipping charge relative to item price — a "low item price, inflated shipping" structure is something Etsy's own ranking approach is designed to work against, not a way to game the system.

### 2.6 What NOT to do (directly contradicts common third-party SEO advice)
- Don't renew/relist repeatedly chasing the temporary "new listing" boost — Etsy explicitly calls this an ineffective use of time versus improving tags or conversion rate.
- Don't judge your ranking by searching your own shop — personalization means your results aren't representative of what other buyers see; use Shop Stats' actual traffic/search-term data instead.
- Don't assume Etsy Plus, Star Seller, or Etsy Ads move your organic placement — none of them do, per Etsy's own statement.

---

## 3. Step Sequence

### STEP 1 — Pull inputs from Phase 2 `[AGENT-READY]`
**Action:** Take the finished composite/mockup image(s) from Phase 2, and the piece's Style Spec values (Mood, Content Type, Color Role, etc.) — determined in Phase 1 and passed through Phase 2 unchanged — as the source material for everything below.
**Validation:** All required inputs present — composite image, style values, piece dimensions.

### STEP 1b — Generate the missing photo types `[AGENT-ASSISTED — human confirms]`
**Action:** Phase 2 only produces the Lifestyle type (§2.4a). Generate or capture the remaining applicable types before moving to Step 2:
- **Studio** — the art alone (framed, per Phase 2's frame decision) on a plain, well-lit, neutral background. No room scene.
- **Detail** — a close-up crop showing print/paper texture or frame edge/corner.
- **Scale** — the piece shown against a size reference (a room scene with a human figure, or a ruler/measurement overlay), reusing Phase 2's already-computed sizing math rather than re-deriving it.
- **Group** — only if this listing bundles multiple sizes/variants.
- **Packaging** — only if fulfillment is physical/printed, not digital download.
**Validation:** Studio and Detail exist for every listing (treated as required, per §2.4a); Scale exists if size is likely to be a buyer hesitation for this piece; Group/Packaging only generated when actually applicable — don't produce them speculatively.

### STEP 2 — Select and order photos `[AGENT-ASSISTED — human confirms hero shot]`
**Action:** From the full set now available (Lifestyle from Phase 2, plus Studio/Detail/Scale/Group/Packaging from Step 1b), select up to 10 and order them. Lead with the Studio shot as the primary hero/thumbnail candidate — Etsy's own guidance favors a "clear, bright photo that shows off the product" for the first slot, which is what Studio is built for; Lifestyle and the rest follow. Confirm every photo meets §2.4's technical requirements.
**Validation:** At least Studio, Lifestyle, and Detail are present; first photo is Studio or another clear/bright shot, not a busy or low-contrast composite; all photos pass the 635px floor, ideally 2000px+; photos work at both square and rectangular crops.

### STEP 3 — Draft title `[AGENT-READY]`
**Action:** Lead with the clearest, most literal descriptor of what the item is — style + subject + product type — since shoppers only see the first few words in search results. Apply Etsy's specific rules: only include an occasion/recipient word if it's essential to what the item literally is (e.g. a genuinely occasion-specific product), not as decoration; keep subjective words ("beautiful," "perfect") out of the title entirely — they belong in the description; never include price.
**Validation:** A shopper skimming mobile search results could tell what this is from the first few words alone; no subjective adjectives; no price; any occasion/recipient language names what the item literally is, not a marketing angle.

### STEP 4 — Fill tags `[AGENT-READY]`
**Action:** Fill all 13 slots per §2.1 — multi-word phrases, diversified across style/room-use/gift/alternate-use angles, balanced broad and long-tail.
**Validation:** All 13 slots used, no near-duplicate tags, at least one gift-angle and one room/use-angle tag present alongside the style descriptors.

### STEP 5 — Fill attributes and category `[AGENT-READY]`
**Action:** Fill every applicable attribute field and select the most specific category (§2.3).
**Validation:** No applicable attribute field left blank.

### STEP 6 — Write description `[AGENT-ASSISTED — human confirms tone]`
**Action:** Structure per Etsy's own guidance: essential information first (dimensions, available sizes/colors, what's included, digital vs. physical, ordering/turnaround details), then the engaging/story content after. Keep it short and informative rather than long-form brand storytelling up front. Work in the tag keywords naturally without keyword-stuffing, and make a specific claim about who the piece is for and what problem it solves — the same specificity principle already grounding this project's positioning (*This Is Marketing*).
**Validation:** Dimensions/specs are readable without scrolling past marketing copy; reads naturally, not as a keyword list; makes a specific "who this is for" claim rather than a generic one.

### STEP 7 — Set shipping and return policy `[HUMAN ONLY — pricing/policy strategy]`
**Action:** Set a return policy; review shipping price framing against §2.5's guidance rather than defaulting to "low item price, high shipping."
**Validation:** Return policy is set; shipping structure doesn't rely on disguising item cost.

### STEP 8 — Publish and log baseline `[AGENT-ASSISTED]`
**Action:** Publish the listing; log the initial state (date, tags used, price, category) for the Performance Tracking module to pick up later.
**Validation:** Listing is live; baseline is logged somewhere retrievable.

---

## 4. Using this doc with AI agents

Same tagging convention as Phase 1 and Phase 2 — `[AGENT-READY]`, `[AGENT-ASSISTED]`, `[HUMAN ONLY]` on every step. This section is the Phase 3 equivalent of Phase 2 §6; Phase 1 and Phase 2 have their own versions, so an agent orchestrating the full pipeline should check the corresponding section in whichever doc it's currently executing rather than assuming only one exists.

**What's genuinely mechanical here:** tags, attributes, category selection, and title construction are rule-following against Etsy's documented factors (§2) — an agent with this doc loaded should produce consistent results without new judgment calls, the same way Phase 2's rule-table steps do.

**What isn't:** hero-photo selection (Step 2) and description tone (Step 6) are agent-assisted with explicit human confirmation, not because the mechanics are unclear but because they're brand-voice calls the rule tables can't fully specify. Shipping/return policy (Step 7) is pricing strategy, not observable from any input — same category as Phase 2's Step 7 weekly review.

**Limitation specific to this doc:** unlike Phase 2's Rule Tables, which are static (the arrangement book doesn't change), §2 here describes a live, Etsy-controlled system. Etsy's own documentation states its search algorithm changes regularly — this doc should be re-verified against the current Seller Handbook periodically, not treated as permanently accurate the way Phase 2's frame/color rules can be.

---

## 5. Scope note — what's deferred

- **eBay, Amazon, Own-site modules** are deferred behind a Platform Expansion Gate: expansion to a new platform is triggered by Performance Tracking data showing Etsy is working, not by a calendar date. Each, when built, needs its own official-documentation research pass the same way this module used Etsy's Seller Handbook — none of Etsy's mechanics above should be assumed to transfer, since each platform's ranking logic is genuinely different (Amazon's Buy Box/A9-A10, eBay's Cassini, and "Own site" has no built-in marketplace demand at all).
- **Performance Tracking module** is not yet built. It needs a sourcing decision first: *Lean Analytics* (Croll & Yoskovitz) was identified as a well-regarded framework for it, but isn't currently in this project's knowledge base the way the other 8 docs are — would need to be added if you want it held to the same citation standard.
- **Engagement and Pricing/Positioning tracks** are not yet built, but unlike the above, they need no new research — they're already grounded in docs already in this project (*The Art of Small Business Social Media* for Engagement; *Influence*, *This Is Marketing*, and *The Paradox of Choice* for Pricing/Positioning).
