# Phase 1: Style-Spec Determination & Art Generation

**Purpose:** determine the style-level and per-scene axis values (Tracks A & B), then generate and cull the finished art that uses them (Track C). Output = the filled Style Spec, plus a finished piece, both ready to hand to Phase 2 Step 1.

**Sources:** business-strategy claims are grounded in *The Paradox of Choice*, *Influence*, *The Art of Small Business Social Media*, and *This Is Marketing* only. Decoration/axis-definition claims are grounded in the arrangement docs only (page citations as in the Phase 2 doc). Anything else (general research technique) is flagged as unsourced practical guidance. **Citation note:** the arrangement docs carry page numbers throughout because their source scan has them embedded; the four business-strategy PDFs don't expose reliable page numbers the same way, so those citations use chapter titles where possible instead — a real difference in source format, not a lower sourcing standard.

---

## 1. The Style Spec (fill in once per style, reuse every week)

This is the schema Tracks A, B, and C below fill in. Every decision in the Phase 2 doc is a lookup against this spec, not a fresh judgment call — Phase 2 reads it, it doesn't define it. Two axes are set once per style; the rest are set per scene template. Write it once per style (Japandi, boho, etc.) and store it. `§` citations below point to Phase 2's Rule Tables, which define what each axis *controls* once known — Track A/B here determine what the value actually *is*.

**Set once per style (not per scene):**
| Axis | What it controls (Phase 2) | Possible values | Determined by |
|---|---|---|---|
| **Mood** | frame material finish, frame form, color pairing (complementary/tension), arrangement mood-layer (§2.7a), focal intensity | calm/ordered ↔ bold/active | Track A, Step A2 |
| **Content type** | frame material category (§2.1 Step A), frame contour, matting technique trigger for close framing (§2.4b) | detailed/representational ↔ minimalist/modern ↔ portrait/still-life | Track A, Step A3 |
| **Frame Form** | perimeter shape (§2.2) | angular/straight-edged ↔ rounded/softer | Track A, Step A4 |

**Set per scene template:**
| Axis | What it controls (Phase 2) | Possible values | Determined by |
|---|---|---|---|
| **Wall condition** | match vs. contrast frame choice (§2.3) | neutral/plain ↔ busy/patterned | Track B, Step B1 |
| **Furniture weight** | weight-balance check (§2.9) | light ↔ dark | Track B, Step B2 |
| **Room type** | eye-level rule (§2.10) | seated room (living/dining) ↔ hallway ↔ no-furniture wall | Track B, Step B3 |
| **Room shape/proportion** | space tips — content line orientation (§2.5a) | narrow ↔ low-ceilinged ↔ small/closed-in ↔ none of these | Track B, Step B4 |
| **Space math** | placement branch (§2.5) | furniture-anchored (single/set) ↔ wide-open no furniture (split-wall) ↔ architectural nook ↔ horizontal surface (propped/easel) | Track B, Step B5 |
| **Color role** | mat intensity, accessory/wall echo, saturation technique (§2.2a) | accent-highlighter ↔ color-burst ↔ unifier ↔ saturator ↔ line-only (no color) | Track B, Step B6 |

A style is complete when Mood, Content Type, and Frame Form are set once, and every scene template has values for all six per-scene axes. Phase 2's Step 0 should only ever need to *read* this table — it shouldn't need to infer or re-derive any value.

There are two tracks below that fill in this schema, run on different schedules:
- **Track A — style-level axes** (Mood, Content Type, Frame Form): run once per *new style*, infrequent.
- **Track B — per-scene axes** (Wall Condition, Furniture Weight, Room Type, Room Shape/Proportion, Space Math, Color Role): run once per *new scene template*, infrequent.

---

## Track A: Style-level axes

### STEP A0 — Validate the style is worth pursuing `[AGENT-READY for the research — human confirms the go/no-go]`
**Action:** Run the research template below (adapted for the candidate style) through Claude's Research feature. Sample listings across many independent shops/sources, not one bestseller list; cross-check against at least two independent signals (e.g. Pinterest, Google Trends). Compute demand-to-competition ratio rather than trusting raw popularity or a single "bestseller" badge.
**Grounding:** *This Is Marketing*, Ch. 4 "The Smallest Viable Market" and Ch. 8 "More of the Who: Seeking the Smallest Viable Market" — the smallest-viable-audience principle argues for a defensible specific position over chasing the highest-volume category; *The Paradox of Choice* — the maximizer trap is chasing "the best" trend signal instead of a genuinely defensible one.
**Validation:** Can you name the specific demand-to-competition finding that justifies this style (not just "it's popular")? Read the research output yourself before locking — the agent runs the methodology, but the go/no-go call on committing a week's production to this style stays a human read of the findings, not an automated pass/fail.

**Reusable research template** (fill in `[STYLE NAME]` and run via Research):

> Research what types of wall art designs are most likely to sell well in the **[STYLE NAME]** style for a wall-hanging/print business, using a methodology that avoids the pitfalls of naively trusting Etsy "bestseller" labels (skewed by shop-level SEO/marketing strength, listings with hundreds of size/color variants inflating apparent demand, and recency-based badge algorithms rather than true sustained demand).
>
> Methodology:
> 1. Sample wall art listings across many different independent Etsy shops (not one bestseller list) searching **[STYLE NAME]** wall art, plus 2–3 closely adjacent style terms if relevant.
> 2. Identify recurring design attributes across listings from *different* shops — subject matter, color palette, composition style, texture/medium look.
> 3. Cross-check the style's demand signal against at least one independent platform (Pinterest trend/search volume, Google Trends) — a pattern holding across multiple independent sources is more trustworthy than any single platform.
> 4. Estimate competition density (approximate listing count) alongside demand, and compute a demand-to-competition ratio — a smaller-volume style with low competition can beat a high-volume, oversaturated one.
> 5. Output a findings table: style/theme → recurs across N independent shops → approximate competition density → confirmed (or not) on the cross-check platform → recommended demand-to-competition verdict.

### STEP A1 — Build a reference set `[AGENT-ASSISTED — human curates]`
**Action — search process:**
1. Search retailer style guides first (e.g. "West Elm [STYLE NAME] style guide," "CB2 [STYLE NAME]," "IKEA [STYLE NAME]") — these are authoritative named-style descriptions, not just visually-similar-but-mislabeled content.
2. Search Pinterest for **[STYLE NAME] wall art**, **[STYLE NAME] gallery wall**, and **[STYLE NAME] living room** (or the relevant space) — three separate queries, not one, to catch both product-only and in-situ shots.
3. Search 1–2 interior design blogs/magazines for written characteristic descriptions of the style (palette, materials, mood words) to cross-check what the images seem to show against what's explicitly named.
4. Cap any single source (one shop, one blog, one Pinterest board) at roughly 3–4 images in the final set — mirrors the A0 principle of not trusting one source's signal.

**Action — what makes an image a valid reference:**
| Requirement | Why |
|---|---|
| Shows the piece actually framed and/or hung in a room, not just a flat product photo on white background | Frame Form (A4) and Mood (A2) can't be judged without seeing how the piece is actually framed and styled |
| At least a third of the set is close-up/product-only shots of the art itself | Needed to judge Content Type (A3) — representational vs. minimalist vs. portrait/still-life detail can be hard to read in a full room shot |
| Attributed to the target style by more than one independent source (appears under that style's name in at least 2 of the searches above, not just one shop's own product tagging) | A single shop's SEO-tagged listing isn't reliable evidence the piece actually reads as that style — same logic as not trusting one bestseller badge in A0 |
| Source is a retailer, design publication, or a Pinterest pin with a real originating source (not an unattributed re-post) | Keeps the reference set traceable if you need to recheck it later |

**Validation:** References span multiple independent sources (per the cap above), include both in-situ and close-up shots, and each image is attributable to the style by more than one source — not assembled from a single board or shop.
**Grounding:** Unsourced — general research technique, not from either document set.

### STEP A2 — Sort into Mood `[AGENT-ASSISTED — human confirms]`
**Action:** The book's own mood passage (p. 56–57, framed around "Are you a rule-follower or a rule-breaker?") is a personal gut-check, not an observable checklist — and p. 56 itself carries some OCR noise in the source scan, so treat the exact wording there as directionally reliable rather than a verbatim quote. Apply these four concrete markers instead, drawn from cleaner-OCR passages elsewhere in the same book, to the reference set:

| Marker | Calm/ordered indicates | Bold/active indicates |
|---|---|---|
| Wall/art color relationship | Complementary or softened-intensity pairing (p. 88) | Deliberate tension — wall and art colors that aren't complementary, creating "vibration"/energy (p. 88) |
| Density of the display | One vivid centerpiece with everything else quieted down (p. 89), or a formal cluster (p. 74, "anchoring central piece") | Salon-style — many pieces/frames of different styles "poured onto the wall" (p. 74, p. 81) |
| Arrangement symmetry | Precise, symmetric alignment (p. 68–69) | Slightly off-kilter, asymmetric arrangement (p. 68–69) |
| Framing weight | Quiet, subtle frames even on a focal piece (p. 27–28) | Oversized/impressive frames used to command attention (p. 27–28) |

Score each reference image against the four markers; a set that lands mostly in one column supports that Mood value. A genuinely mixed scorecard means the reference set itself isn't focused enough yet — narrow it (return to A1) rather than forcing a call.
**Validation:** Can you point to 3+ reference images that clearly support the chosen mood *against at least two of the four markers*, not just a general impression? A mixed/ambiguous scorecard means the style isn't focused enough yet — narrow the reference set before locking (satisficer principle, *The Paradox of Choice*: commit to a bar, don't keep the option open indefinitely).

### STEP A3 — Sort into Content Type `[AGENT-ASSISTED — human confirms]`
**Action:** Match the reference imagery's actual subject/rendering style against the three-way definition: detailed/representational, minimalist/modern, or portrait/still-life (p. 19).
**Validation:** Re-check the frame contour table (Phase 2 §2.2) against what the references actually show framed — if the predicted contour doesn't match what you see, the Content Type call is probably wrong.

### STEP A4 — Sort into Frame Form `[AGENT-ASSISTED — human confirms]`
**Action:** Look at how the style is typically framed across the references — angular/straight-edged or rounded/softer (p. 19).
**Validation:** Consistent across most references, or mixed? If mixed, mood is the tiebreaker — bold moods more often tolerate mixed/salon-style framing (Phase 2 §2.7a); calm moods should converge on one form.

### STEP A5 — Lock the style-level entry `[HUMAN ONLY]`
**Action:** Record Mood, Content Type, and Frame Form as this style's locked values in the Style Spec.
**Grounding:** *This Is Marketing* — "specific is brave": vague values produce generic output, which defeats the niche's whole premise.
**Validation:** Could someone unfamiliar with the style read these three values alone and generate a reasonably on-style prompt? If not, they're too vague — return to A1 and narrow the reference set.

---

## Track B: Per-scene axes

Run once per scene template (e.g. "behind sofa — light neutral," "behind sofa — dark sofa," "patterned wall").

### STEP B0 — Confirm the scene template is fixed `[HUMAN ONLY]`
**Action:** Confirm this is a reusable mockup template (per Phase 2's 3-templates-per-space guidance), not a one-off generated room.
**Validation:** Template is saved/reusable, not regenerated per piece.

### STEP B1 — Wall Condition `[AGENT-READY]`
**Action:** Observe the wall: neutral/plain or busy/patterned (Phase 2 §2.3).
**Validation:** Apply the book's own test — would a frame need to "read distinctly" against this wall to avoid disappearing (p. 61)? If yes, it's busy/patterned. **If genuinely borderline** (a subtle texture or very low-contrast pattern), default to neutral/plain — the match-vs-contrast rule this feeds is more forgiving of a false "plain" than a false "busy."

### STEP B2 — Furniture Weight `[AGENT-READY]`
**Action:** Observe the furniture: light or dark (Phase 2 §2.9).
**Validation:** Weight is driven by color *and* size together, not color alone — confirm both before recording. **If genuinely borderline** (mid-tone furniture), record whichever the *frame material* decision (§2.1) would need to be safe — a light default keeps the art-weight/furniture-weight check from silently failing later.

### STEP B3 — Room Type `[AGENT-READY]`
**Action:** Classify as seated room (living/dining), hallway, or no-furniture wall (Phase 2 §2.10).
**Validation:** This determines which eye-level formula Phase 2 Step 6 will use — confirm the right one applies before moving on. **If genuinely ambiguous** (e.g. a hallway with a bench), this one doesn't have a safe default — flag it for a human decision rather than guessing, since the eye-level formulas aren't interchangeable and a wrong guess silently breaks Step 6's math.

### STEP B4 — Room Shape/Proportion `[AGENT-READY]`
**Action:** Classify as narrow, low-ceilinged, small/closed-in, or none of these (Phase 2 §2.5a).
**Validation:** "None of these" is a legitimate, common answer — don't force a fit. **If genuinely borderline** between a category and "none of these," default to "none of these" — this axis only adds a generation constraint when confidently triggered; a false negative just skips an optional space-tip, while a false positive forces an unnecessary constraint on Track C's generation.

### STEP B5 — Space Math `[AGENT-READY]`
**Action:** Measure the scene: furniture-anchored with room for one piece (single), furniture-anchored with room for more (set), wide-open/no furniture (split-wall), architectural nook, or horizontal surface (propped/easel) (Phase 2 §2.5).
**Validation:** This is arithmetic against actual scene dimensions, not preference — measure before deciding.

### STEP B6 — Color Role `[AGENT-READY for steps 1 & 3 — human confirms the override call in step 2]`
**Action:** Steps 1 and 3 are observation and lookup, same as B1–B5; step 2 is the one genuinely strategic call. Work through in order:

1. **Observe the scene's existing color state** and match to the closest description:

| What you observe in the scene | Candidate role |
|---|---|
| Predominantly neutral/muted, no strong existing color anywhere | Color-burst (the piece becomes the room's one saturated note, p. 91) |
| One existing accent color present but understated, easy to miss | Accent-highlighter (p. 82) |
| Multiple scattered color touches (pillows, throw, small objects) not yet visually tied together | Unifier (p. 84) |
| A clear dominant color theme already established throughout | Saturator (p. 91) |

2. **Check against Content Type (Track A).** If Content Type is minimalist/modern with heavy negative space (a Japandi-type spec), Line-only is the documented default (§2.2a, p. 97) and should override step 1 — **unless you (human) have a specific catalog-strategy reason to make this scene a deliberate color statement within an otherwise monochrome catalog.** This is the one sub-step in B6 that isn't observable from the image and needs an explicit human call.
3. **Cross-check against B1/B2, already recorded.** Does the candidate role still make sense given this scene's actual Wall Condition and Furniture Weight? E.g. Color-burst assumes a neutral backdrop — if B1 already logged this wall as busy/patterned, Color-burst is likely the wrong call; Unifier assumes visible scattered accents, which may not coexist with a very plain/empty scene.

**Validation:** Does the final choice survive both cross-checks (step 2 and step 3), not just the initial observation in step 1? If the Content Type check or the B1/B2 check contradicts the step-1 candidate, resolve the conflict explicitly rather than defaulting to whichever was decided first.

### STEP B7 — Lock the per-scene entry `[HUMAN ONLY]`
**Action:** Record all six per-scene values for this template.
**Validation:** Could someone who has never seen the scene photo make correct placement/frame decisions from these six values alone? If not, a value is under-specified — go back and sharpen it.

---

## Track C: Art generation

Run daily, once Track A and Track B outputs exist for the style/scene in use. This is the execution step — turning the locked spec into an actual finished, culled piece.

### STEP C1 — Generate art `[AGENT-ASSISTED — human enforces batch cap]`
**Action:** Run the prompt template, capped batch (e.g. 6–8 generations, no re-rolling past that), filtered by the Mood and Content Type values locked in Track A. If this scene's Room Shape/Proportion (Track B4) is narrow, low-ceilinged, or small/closed-in, apply the matching space tip (Phase 2 §2.5a — favor horizontal lines, vertical lines, or a faraway-vista landscape respectively) as an added generation constraint.
**Validation:** Batch matches the style spec (palette, motif family) — pass/fail checklist. If a space tip applies, generated content reflects the required line orientation or vista. The cap is enforced regardless of how the batch looks — no "just one more" passes (satisficer principle, *The Paradox of Choice*).

### STEP C2 — Cull to finalists `[AGENT-ASSISTED — human makes final pick]`
**Action:** Keep the top 1–2 from the batch.
**Validation:** Can you name a specific reason a further regeneration would beat these? If not, stop. This judgment stays with a human — agents are unreliable at recognizing "good enough" versus chasing marginal improvement.

**Output of Track C:** one finished, culled piece (or small culled set), ready to hand to Phase 2 Step 1.

---

## Output handoff to Phase 2

Track A's output (once per style) plus Track B's output (once per scene template) together constitute the complete Style Spec defined in §1 above — Phase 2 Step 0 reads this table directly and should not have to infer or re-derive any of these nine values. Track C's output (a finished, culled piece) is the actual input to Phase 2 Step 1, which starts the placement/framing/compositing work.
