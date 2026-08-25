# Extraction Manifest — Set The Wall Knowledge Base

**Purpose:** ground-truth inventory of everything in the three source phase docs that must survive
extraction into the `plan.md` files. This is the checklist used to verify no content was dropped or
altered. Generated mechanically (grep/wc/md5) from the live project files, not from reading.

**Generated:** 2026-08-24

---

## 0. Source fingerprints

Verify these before trusting any extraction. If a hash differs, the doc changed after this manifest
was built and the extraction must be re-verified against the new version.

| File | Lines | MD5 |
|---|---|---|
| `setthewall-phase1-style-spec-determination.md` | 171 | `607866ee9e185b763482f932055e7249` |
| `setthewall-phase2-decor-system.md` | 375 | `21dfd86c3a847f393b4ef17f8a8dd930` |
| `setthewall-phase3-module1-etsy-listing.md` | 142 | `a0c067d7a660c3447369d099433dfb8f` |

**Totals to account for:**
- **38 steps** (16 Phase 1 + 13 Phase 2 + 9 Phase 3)
- **24 markdown tables** (5 + 17 + 2)
- **105 table data rows** (excluding header rows)
- **21 Phase 2 rule sections** (§2.1–§2.12 including sub-lettered)
- **7 Phase 3 rule sections** (§2.1–§2.6 including sub-lettered) + §1 search mechanism
- **40 distinct page citations** in Phase 2; **13** in Phase 1

---

## 1. Step inventory (38 steps)

Every step must appear in exactly one plan module, with its ownership tag preserved verbatim.

### Phase 1 — 16 steps

| Step | Title | Ownership tag | Target module |
|---|---|---|---|
| A0 | Validate the style is worth pursuing | `[AGENT-READY for the research — human confirms the go/no-go]` | 01 |
| A1 | Build a reference set | `[AGENT-ASSISTED — human curates]` | 01 |
| A2 | Sort into Mood | `[AGENT-ASSISTED — human confirms]` | 01 |
| A3 | Sort into Content Type | `[AGENT-ASSISTED — human confirms]` | 01 |
| A4 | Sort into Frame Form | `[AGENT-ASSISTED — human confirms]` | 01 |
| A5 | Lock the style-level entry | `[HUMAN ONLY]` | 01 |
| B0 | Confirm the scene template is fixed | `[HUMAN ONLY]` | 02 |
| B1 | Wall Condition | `[AGENT-READY]` | 02 |
| B2 | Furniture Weight | `[AGENT-READY]` | 02 |
| B3 | Room Type | `[AGENT-READY]` | 02 |
| B4 | Room Shape/Proportion | `[AGENT-READY]` | 02 |
| B5 | Space Math | `[AGENT-READY]` | 02 |
| B6 | Color Role | `[AGENT-READY for steps 1 & 3 — human confirms the override call in step 2]` | 02 |
| B7 | Lock the per-scene entry | `[HUMAN ONLY]` | 02 |
| C1 | Generate art | `[AGENT-ASSISTED — human enforces batch cap]` | 03 |
| C2 | Cull to finalists | `[AGENT-ASSISTED — human makes final pick]` | 03 |

### Phase 2 — 13 steps

| Step | Title | Ownership tag | Target module |
|---|---|---|---|
| 0 | Load the style spec *(weekly)* | `[HUMAN ONLY]` | 04 |
| 1 | Measure the scene, choose placement branch *(daily)* | `[AGENT-READY]` | 04 |
| 2a | Single piece: confirm focal treatment | `[AGENT-READY]` | 04 |
| 2b | Multi-piece set: grouping form and count | `[AGENT-READY]` | 04 |
| 2c | Split-wall: zone the wall | `[AGENT-READY]` | 04 |
| 2d | Architectural nook: fit to the space | `[AGENT-READY]` | 04 |
| 2e | Surface/propped display: height and lean | `[AGENT-READY]` | 04 |
| 3 | Unify by theme *(daily, if a set)* | `[AGENT-ASSISTED — vision check, human confirms]` | 04 |
| 4 | Assign frame material and contour *(daily)* | `[AGENT-READY]` | 04 |
| 4b | Color function check *(daily)* | `[AGENT-READY]` | 04 |
| 5 | Check weight balance *(daily)* | `[AGENT-READY]` | 04 |
| 6 | Composite into the scene *(daily)* | `[NOT AN AGENT/LLM TASK — deterministic template tool required]` | 04 |
| 7 | Weekly review gate | `[HUMAN ONLY — agent may summarize data, not decide]` | 06 / 07 |

### Phase 3 — 9 steps

| Step | Title | Ownership tag | Target module |
|---|---|---|---|
| 1 | Pull inputs from Phase 2 | `[AGENT-READY]` | 05 |
| 1b | Generate the missing photo types | `[AGENT-ASSISTED — human confirms]` | 05 |
| 2 | Select and order photos | `[AGENT-ASSISTED — human confirms hero shot]` | 05 |
| 3 | Draft title | `[AGENT-READY]` | 05 |
| 4 | Fill tags | `[AGENT-READY]` | 05 |
| 5 | Fill attributes and category | `[AGENT-READY]` | 05 |
| 6 | Write description | `[AGENT-ASSISTED — human confirms tone]` | 05 |
| 7 | Set shipping and return policy | `[HUMAN ONLY — pricing/policy strategy]` | 05 |
| 8 | Publish and log baseline | `[AGENT-ASSISTED]` | 05 |

**Ownership tag totals to preserve:**
- Phase 1: 5 plain `[AGENT-READY]`, 2 qualified AGENT-READY, 6 `[AGENT-ASSISTED]` variants, 3 `[HUMAN ONLY]`
- Phase 2: 9 step-level `[AGENT-READY]`, 2 `[AGENT-ASSISTED]` variants, 2 `[HUMAN ONLY]` variants, 1 `[NOT AN AGENT/LLM TASK]`
- Phase 3: 5 `[AGENT-READY]`, 4 `[AGENT-ASSISTED]` variants, 1 `[HUMAN ONLY]`

---

## 2. Table inventory (24 tables, 105 data rows)

Each table becomes a YAML rule file or a schema enum. Row counts are the verification target — an
extraction with fewer rows than listed has dropped content.

### Phase 1 — 5 tables

| # | Location | Table | Data rows | Becomes |
|---|---|---|---|---|
| P1-T1 | §1 L15 | Style-level axes (Mood, Content Type, Frame Form) | 3 | `style_specs/` schema |
| P1-T2 | §1 L22 | Per-scene axes (6 axes) | 6 | `style_specs/` scenes schema |
| P1-T3 | A1 L65 | Valid reference image requirements | 4 | `prompts/a1_reference_set.md` |
| P1-T4 | A2 L78 | Four mood markers (calm vs bold) | 4 | `prompts/a2_mood.md` + schema |
| P1-T5 | B6 L136 | Color role observation → candidate role | 4 | `rules/color_role.yml` |

### Phase 2 — 17 tables

| # | Location | Table | Data rows | Becomes |
|---|---|---|---|---|
| P2-T1 | §2.1 L24 | Frame material category | 7 | `rules/frame_material.yml` |
| P2-T2 | §2.1 L35 | Metal finish/color sub-table | 4 | `rules/frame_material.yml` |
| P2-T3 | §2.2 L46 | Frame form (perimeter shape) | 2 | `rules/frame_form_contour.yml` |
| P2-T4 | §2.2 L53 | Frame contour by Content Type | 3 | `rules/frame_form_contour.yml` |
| P2-T5 | §2.2a L62 | Color function (5 roles) | 5 | `rules/color_role.yml` |
| P2-T6 | §2.2b L79 | Lighting fixture types | 4 | `rules/lighting.yml` |
| P2-T7 | §2.2b L87 | Bulb types | 4 | `rules/lighting.yml` |
| P2-T8 | §2.3 L99 | Match vs. contrast by wall condition | 2 | `rules/match_contrast.yml` |
| P2-T9 | §2.4b L116 | Matting technique (conditional) | 7 | `rules/matting.yml` |
| P2-T10 | §2.5 L127 | Space math → placement branch | 5 | `rules/placement_branch.yml` |
| P2-T11 | §2.5a L136 | Space tips (line orientation) | 3 | `rules/space_tips.yml` |
| P2-T12 | §2.5b L144 | Location suitability factors | 5 | `rules/location_suitability.yml` |
| P2-T13 | §2.7 L163 | Six standard arrangement forms | 6 | `rules/arrangement_forms.yml` |
| P2-T14 | §2.7a L173 | Mood-driven arrangement modifier | 2 | `rules/arrangement_forms.yml` |
| P2-T15 | §2.8 L182 | Count and focal dynamic | 3 | `rules/count_focal.yml` |
| P2-T16 | §2.10 L194 | Eye level by room type | 3 | `rules/eye_level.yml` |
| P2-T17 | §2.11 L201 | Spacing — four distinct rules | 4 | `rules/spacing.yml` |

### Phase 3 — 2 tables

| # | Location | Table | Data rows | Becomes |
|---|---|---|---|---|
| P3-T1 | §1 L19 | Etsy ranking factors | 8 | `rules/etsy_ranking.yml` |
| P3-T2 | §2.4a L61 | Seven photo types | 7 | `rules/etsy_photos.yml` |

---

## 3. Non-table rule blocks — HIGH OMISSION RISK

These are prose or bullet rules, not tables. They are the most likely content to be silently dropped
because they don't show up in a table scan. **Every item below must be verified present.**

### Phase 2 §2 — embedded prose rules

| ID | Location | Rule | Must appear in |
|---|---|---|---|
| P2-P1 | §2.2a L69 | **Mat intensity rule** (p. 84) — dark mat intensifies; thin/off-white lets colors interact | `rules/matting.yml` |
| P2-P2 | §2.2a L71 | **Wall/light interaction** (p. 84) — light direction, bulb temperature | `rules/lighting.yml` |
| P2-P3 | §2.2a L73 | **Complementary vs. tension pairing** (p. 88) — calm→complementary, bold→tension OK | `rules/color_role.yml` |
| P2-P4 | §2.2b L93 | **Conservation note** — UV glass, incandescent over fluorescent | `rules/customer_education.yml` |
| P2-P5 | §2.2b L95 | **Color-choreography technique** (p. 86) — sightline color stripping | `rules/color_role.yml` |
| P2-P6 | §2.3 L103 | **Governing principle (p. 20)** — frame serves the *picture*, not the room; table is tiebreaker only | `rules/match_contrast.yml` |
| P2-P7 | §2.3 L105 | **Single piece vs. group conditional (p. 21)** — matching matters more for a lone piece | `rules/match_contrast.yml` |
| P2-P8 | §2.4 L108–109 | Frame-to-piece sizing — bigger art→bigger frame; small art→delicate **unless** deliberate oversized exception | `rules/frame_sizing.yml` |
| P2-P9 | §2.4a L112 | **Mat sizing rule (p. 21–22)** — mat visibly wider than frame; equal reads flat; uneven mat adds movement | `rules/matting.yml` |
| P2-P10 | §2.5c L152 | **Wall coverage cap (p. 51)** — two-thirds max, or commit fully maximalist; binary, no in-between | `rules/coverage_cap.yml` |
| P2-P11 | §2.6 L155–157 | **Focal point mechanism (p. 27–28)** — isolation+oversized frame = focal; cluster+thin frame = blends. Both bullets. | `rules/focal_point.yml` |
| P2-P12 | §2.7b L178 | **Symmetry vs. subject energy (p. 68–69)** — subject energy wins conflicts; bookend element | `rules/arrangement_forms.yml` |
| P2-P13 | §2.9 L188–190 | **Weight balance (p. 63)** — 3 bullets incl. "size AND color/material" | `rules/weight_balance.yml` |
| P2-P14 | §2.10 L197 | **General rule of thumb** — drop 3–4"; most people hang too high | `rules/eye_level.yml` |
| P2-P15 | §2.12 L209–214 | **Theme unification (p. 101)** — 6 bullets: limit count, similarity beyond subject, proximity, repeat-don't-duplicate, shape dominance (p. 116–117), subdivision strategies | `rules/theme_unification.yml` |

### Phase 2 §5 — additional notes (customer-education content, NOT daily pipeline)

| ID | Location | Content | Must appear in |
|---|---|---|---|
| P2-N1 | §5 L318 | **Happy Surprises (p. 60)** — unconventional placements | `rules/customer_education.yml` |
| P2-N2 | §5 L320 | **No-holes planning method (p. 57)** — paper templates | `rules/customer_education.yml` |
| P2-N3 | §5 L322–326 | **Safekeeping/conservation checklist (p. 23–24, 85)** — 4 bullets | `rules/customer_education.yml` |
| P2-N4 | §5 L328–332 | **Professional framer checklist (p. 24)** — 4 bullets | `rules/customer_education.yml` |
| P2-N5 | §5 L334 | **Easel display (p. 37)** — distinct from propped surface display | `rules/customer_education.yml` |
| P2-N6 | §5 L336 | **Hanging hardware by weight (p. 40–41)** — sawtooth/wire/corner/anchor | `rules/customer_education.yml` |

### Phase 3 §2 — bullet rules

| ID | Location | Rule | Must appear in |
|---|---|---|---|
| P3-P1 | §2.1 L36–39 | Tags — 13 slots, multi-word/long-tail, diversify angles, broad+specific balance | `rules/etsy_tags.yml` |
| P3-P2 | §2.2 L42–43 | Title — literal descriptor first; word order does NOT affect ranking; AI-title tool caveat | `rules/etsy_title.yml` |
| P3-P3 | §2.3 L46–47 | Attributes — fill every applicable; most specific category | `rules/etsy_attributes.yml` |
| P3-P4 | §2.4 L50–55 | Photos — file types, **635px floor vs 2000px target (do not conflate)**, 10 slots, crop ratios, first-photo weight, + flagged third-party 4:3–5:4 crop tip | `rules/etsy_photos.yml` |
| P3-P5 | §2.5 L71–72 | Return policy named in ranking; shipping price factored into US ranking | `rules/etsy_policy.yml` |
| P3-P6 | §2.6 L75–77 | What NOT to do — 3 bullets (don't relist-chase, don't self-search, Plus/StarSeller/Ads don't rank) | `rules/etsy_antipatterns.yml` |
| P3-P7 | §1 L29 | What does NOT affect ranking — Etsy Plus, Star Seller, Etsy Ads | `rules/etsy_ranking.yml` |

### Phase 1 — embedded content

| ID | Location | Content | Must appear in |
|---|---|---|---|
| P1-P1 | A0 L47–54 | **Reusable research template** — 5-point methodology, verbatim blockquote | `prompts/a0_style_validation.md` |
| P1-P2 | A1 L58–61 | **Search process** — 4 numbered steps (retailer guides, 3 Pinterest queries, blogs, 3–4 cap per source) | `prompts/a1_reference_set.md` |
| P1-P3 | A2 L75 | **OCR caveat on p. 56** — treat wording as directional, not verbatim | `rules/README.md` provenance note |
| P1-P4 | B1–B4 | **Borderline-default rules** — B1→neutral, B2→light, B3→**no safe default, flag human**, B4→"none of these" | `rules/borderline_defaults.yml` |
| P1-P5 | B6 L142–143 | **Steps 2 & 3** — Content Type override (line-only default, p. 97) + B1/B2 cross-check | `rules/color_role.yml` |
| P1-P6 | §1 L30 | Completeness rule — style complete when 3 style-level + 6 per-scene set for every template | `00` validation logic |

---

## 4. Cross-doc integration points

These must not be dropped — they are what makes the three docs one pipeline.

| ID | Content | Module |
|---|---|---|
| X1 | Phase 1 §1 is the schema; Phase 2 only *reads* it, never derives it | 00, 04 |
| X2 | Phase 1 Track C output → Phase 2 Step 1 input | 03→04 |
| X3 | Phase 2 Step 6 composite → Phase 3 Step 1 input (documented both ends) | 04→05 |
| X4 | Phase 3 Lifestyle photo type == Phase 2 Step 6 composite | 05 |
| X5 | Phase 3 Scale photo reuses Phase 2 sizing math, doesn't re-derive | 05 |
| X6 | Phase 2 §6 cross-pipeline human-gate rollup (all three docs) | 06 |
| X7 | Style-spec drift warning (Phase 2 §6 Limitation 3) | 07 |
| X8 | Phase 3 §4 — Etsy rules are live/changing, need periodic re-verification (unlike static Phase 2 rules) | 07 |

---

## 5. Human gates — canonical list (from Phase 2 §6 rollup + inline tags)

Every one must be an explicit pause state in module 06.

**Phase 1:** Track A axis determination (whole track) · A0 go/no-go · A5 lock · B0 template confirm ·
B6 step-2 override call · B7 lock · C1 batch cap enforcement · C2 final cull

**Phase 2:** Step 0 load spec · Step 3 vision-check confirm · Step 7 weekly review

**Phase 3:** Step 1b photo confirm · Step 2 hero shot · Step 6 description tone · Step 7 shipping/returns

---

## 6. Deferred / not-yet-built (must be represented as explicitly out of scope)

| Item | Status |
|---|---|
| Phase 3 Modules: eBay, Amazon, Own-site | Deferred behind Platform Expansion Gate (data-triggered, not calendar) |
| Performance Tracking module | Not built — needs *Lean Analytics* added to KB first |
| Engagement track | Not built — grounded in *The Art of Small Business Social Media* (already in KB) |
| Pricing/Positioning track | Not built — grounded in *Influence*, *This Is Marketing*, *The Paradox of Choice* (already in KB) |

---

## 7. Verification procedure

After all plan modules are drafted:

1. **Hash check** — re-run md5 on the three source docs; confirm unchanged from §0.
2. **Step count** — grep the plan files for each of the 38 step IDs. All present, exactly once.
3. **Tag fidelity** — every ownership tag string matches the source verbatim.
4. **Table row count** — each extracted YAML has ≥ the data-row count in §2.
5. **Prose-rule check** — walk §3 item by item (P2-P1…P3-P7, P1-P1…P1-P6). This is the manual pass;
   these will not be caught by any automated count.
6. **Citation check** — every extracted rule carries its source page/chapter as a comment.
7. **Independent audit** — fresh conversation, source docs + plan files, single instruction:
   "find anything in the source missing, altered, or contradicted in the plans."
