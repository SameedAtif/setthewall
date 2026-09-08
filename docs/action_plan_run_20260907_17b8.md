# Action Plan — run_20260907_17b8 fixes + art-generation pipeline (revised)

**Status:** working plan. **Supersedes** the sequencing in
`# Implementation Plan — run_20260907_17b8 fixes + art-quality research pipeline`
(the "original plan"). Every phase below maps back to that document's section numbers (`§N`),
so this file is read *against* it, not instead of it.

**Excluded (deliberate, per product decision):**
- **§4 — AI-disclosure compliance** (removed from scope).
- **§6 — frame rendering / composite-frame consistency** (deferred: frames may not be sellable).

**Included here but absent from the original plan:** **Phase 0 — conductor rewind semantics**
(a correctness bug found in the developer feedback's bottom line, confirmed against the run:
`A3` and `C2` were `blocked → rewind` but their flagged values still flowed downstream and A5
locked over them).

---

## Conventions used throughout

- **Grounding:** every numeric rule reproduced from the original plan's §0 (coverage cap 0.6667 /
  0.95, single-piece width 2/3–3/4, group ≤ furniture and ≥ half, 8–10″ gap, 5–6″ seated eye level
  + 3–4″ drop, weight-balance, N≥3 recurrence, 300 DPI).
- **Test cases** are written as *descriptions* (not code) with scenario coverage. Each phase lists:
  **happy path**, **failure/negative**, **boundary/edge**, and **regression** (a prior fix that must
  not re-break). Target spec file is named per case.
- **Effort** is relative: `S` (≤ half day), `M` (1–2 days), `L` (multi-day).

---

# Phase 0 — Conductor honors `blocked`/`rewind` (linchpin) — `L`

**Goal.** Today a blocking QA finding writes `disposition: rewind` and then the flow keeps
threading the flagged value. Confirmed in `run_20260907_17b8`:
- `A3`: `contour_cross_check_passed=false`, `verdict=blocked`, `disposition=rewind` — **A5 still ran `ok` and locked `content_type: detailed_representational`.**
- `C2`: `verdict=blocked`, `disposition=rewind` — **the chosen art still flowed into P2_6.**

A `blocked`/`rewind` must *halt downstream threading of that value*, not just write a string.

**Change.**

1. **Taint-aware context.** `Context::Assembler` gains `tainted?(step_id)`: a step is tainted if
   its recorded `disposition` is `rewind`/`abandon` or its `status` is `failed`. Every derived
   value — `reference_images`, `style_name_used`, `mood`, `content_type`, `frame_form`,
   `scene_axes` — treats a tainted source as *absent* (returns `nil` / empty), so the next step
   either gets `nil` and fails cleanly, or (for A5/B7) cannot satisfy its required axes.
2. **Gate provisional locks.** `Context::Assembler#provisional` only returns `confirmed: true` for
   `A5`/`B7` when *every* required axis comes from a clean step. Otherwise no provisional confirm →
   `LockStyleEntry`/`LockSceneEntry` return `fail_step` (their own `invalid_axis` / blank-axis
   checks fire), and the run escalates instead of locking a flagged value.
3. **Surface rewinds.** When `Conductor#close_gate` selects `rewind`, it also calls `escalate!`
   with the blocking QA claim (not just the disposition), so the dossier's "Open questions" shows
   it in plain language.
4. **Stop the cascade (piece side-effects).** When `C2` is rewound, the piece's `chosen_url` /
   `finalist_urls` must not feed `P2_6`. Mark the piece tainted (or clear `chosen_url`) so the
   composite step fails with a clear "no chosen art" instead of silently compositing a rejected
   pick.

**Files.**
- `app/agents/conductor.rb` — `close_gate`, `record_disposition!`, escalation on rewind.
- `app/services/context/assembler.rb` — `tainted?`, and gating in `derived`/`provisional`.
- `app/steps/track_c/cull_to_finalists.rb` (only if piece side-effect needs explicit handling).

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 0.1 | happy: clean step threads normally | A3 `approve`, `result.content_type` set | `Context::Assembler.for("B6")` returns the content_type | `module09_support_spec.rb` |
| 0.2 | negative: rewinded step does not thread | A3 `disposition=rewind` | A5 context has `content_type: nil`; `provisional` returns no `confirmed` | `module09_support_spec.rb` |
| 0.3 | negative: A5 refuses to lock tainted axes | A2/A3/A4 any rewinded | `LockStyleEntry` returns `fail_step` (invalid axis) | `spec/steps/track_a/` |
| 0.4 | negative: C2 rewind blocks composite | C2 `rewind`, chosen_url present | P2_6 does not composite; step fails or escalates | `spec/agents/conductor_spec.rb` |
| 0.5 | regression: clean full run still completes | all gated steps `approve` | `run_speculative(scope: "full")` reaches `awaiting_dossier_review` | `conductor_spec.rb` |
| 0.6 | regression: rewind surfaces in dossier | force one `rewind` | dossier "Open questions" names the step + QA claim in English | `module09_spec.rb` |

---

# Phase 1 — Style-spec `name` split (original §2) — `S`

**Goal.** `name` holds an A0 research sentence; split into a short buyer-facing `name` plus
`production_model.research_focus`.

**Change.**
1. `StyleSpecWriter` writes `name` (buyer-facing) and `production_model.research_focus`
   (A0's verbatim sub-theme).
2. A5 validator: `name` ≤5 words, no parentheses, no price figure, no size range, no
   fulfillment token (`digital|physical|print|download`). Block lock naming the failing condition.
3. Point C1/P3_3/P3_4/P3_6 at `spec.name`; retire the `display_name` slug-derivation (keep as a
   fallback only if `name` is blank, or delete once consumers migrate).

**Files.** `app/knowledge_base/style_spec.rb`, `app/knowledge_base/style_spec_writer.rb`,
`app/steps/track_a/lock_style_entry.rb`, `app/steps/track_c/generate_art.rb`,
`app/steps/phase3/{draft_title,fill_tags,write_description}.rb`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 1.1 | happy | `name: "Whimsigoth celestial"` | spec loads; C1 prompt renders "Whimsigoth celestial" | `validation_spec.rb` |
| 1.2 | boundary: 5 words ok | `name` = exactly 5 words | passes | `validation_spec.rb` |
| 1.3 | boundary: 6 words rejected | `name` = 6 words | A5 lock fails naming word count | `validation_spec.rb` |
| 1.4 | negative: parens rejected | `name: "Foo (bar)"` | lock fails | `validation_spec.rb` |
| 1.5 | negative: price/size/format token rejected | `name` contains "download" / "$12" | lock fails | `validation_spec.rb` |
| 1.6 | regression: P3_4 rule-4 satisfiable | short name present | tags validation passes with style descriptor folded in | `steps_spec.rb` |

---

# Phase 2 — `production_model` wiring (original §1) — `M`

**Goal.** A0's digital-vs-physical and single-vs-set verdict reaches downstream.

**Change.**
1. `production_model` block in the spec (`fulfillment_type`, `piece_count`, `price_tier_usd`,
   `rejected_alternatives`); required before lock.
2. `SpaceMath` (B5) precondition: `piece_count > 1` forbids `single`; escalate with the explicit
   contradiction message.
3. `LoadStyleSpec` (P2_0) conformance: block when `fulfillment_type` ≠ piece `product_type`.
4. Route `production_model.fulfillment_type` into P3_6's `%{fulfillment_type}`.

**Files.** `app/knowledge_base/{style_spec,style_spec_writer}.rb`,
`app/steps/track_b/space_math.rb`, `app/steps/phase2/load_style_spec.rb`,
`app/steps/phase3/write_description.rb`, `knowledge_base/style_specs/whimsigoth-v1.yml`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 2.1 | negative: spec without production_model | locked spec missing the block | loader/validator raises | `validation_spec.rb` |
| 2.2 | negative: B5 must not return `single` | `piece_count: 6`, scene favoring single | B5 returns `set` or escalates (never `single`) | `spec/steps/track_b/` |
| 2.3 | negative: fulfillment mismatch | `fulfillment_type: digital`, piece `product_type: physical_print` | P2_0 blocks with explicit error naming both | `spec/steps/phase2/` |
| 2.4 | happy: match passes | `digital` + digital product | P2_0 passes | `spec/steps/phase2/` |
| 2.5 | boundary: piece_count 1 | `piece_count: 1` | B5 may return `single` | `spec/steps/track_b/` |
| 2.6 | regression: P3_6 fulfillment sourced from spec | spec `fulfillment_type: digital` | description prompt gets `fulfillment_type=digital` | `steps_spec.rb` |

---

# Phase 3 — Placement correctness (original §7) — `L`

**Goal.** Composites are placed from uncalibrated placeholders and `PlacementQa` never runs on P2_6.

**Change.**
1. **Gate P2_6** so `PlacementQa` runs (currently `gate: false`, Tier 2 → conductor skips QA).
   Add to the gated set or special-case in `Conductor#gated?`.
2. **Emit computed geometry.** `Compositor::Runner#measurements_summary` must emit what it
   actually computed: `group_width_px`, `furniture_gap_px`, `drop_applied_inches`, `art_width_px`,
   `art_height_px`, plus `furniture_width_px` — fixing the current mismatch where `PlacementQa`
   reads fields the compositor never emits.
3. **`PlacementQa` checks emitted values** against §0.1 as hard `blocking`: gap 8–10″, width ratio
   0.5–1.0 (single target 0.67–0.75), coverage binary (not 0.6667–0.95), drop 3–4″.
4. **Template metadata validation:** on scene-template load, compare declared
   `image_width_px`/`image_height_px` against the actual image file; raise on mismatch.
5. **Calibrate** `behind_sofa_light_neutral.yml` (real ppi + furniture edges + wall zone), or keep
   `calibrated: false` so committed runs refuse and only speculative dry-runs proceed.

**Files.** `app/services/compositor/runner.rb`, `app/agents/placement_qa.rb`,
`app/agents/conductor.rb`, `knowledge_base/scene_templates/behind_sofa_light_neutral.yml`,
`knowledge_base/rules/decision_rules.yml`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 3.1 | negative: P2_6 is gated | `gated?("P2_6")` | returns true (PlacementQa runs) | `conductor_spec.rb` |
| 3.2 | negative: metadata mismatch | template declares 2400×1600, file is 1408×768 | loader raises | `runner_spec.rb` |
| 3.3 | negative: gap out of band | emitted gap ≈ 13.8″ | PlacementQa `blocking` | `other_agents_spec.rb` |
| 3.4 | boundary: gap exactly 8″ and 10″ | gap 8.0, 10.0 | both pass | `other_agents_spec.rb` |
| 3.5 | negative: width ratio > 1.0 | art wider than furniture | `blocking` | `other_agents_spec.rb` |
| 3.6 | negative: coverage mid-band | coverage 0.8 | `blocking` | `other_agents_spec.rb` |
| 3.7 | boundary: coverage 0.6667 / 0.95 | exactly at the two edges | pass (not mid-band) | `other_agents_spec.rb` |
| 3.8 | regression: uncalibrated template still allows speculative dry-run | `calibrated: false`, speculative | composite produced, `calibrated: false` recorded | `runner_spec.rb` |
| 3.9 | regression: uncalibrated template blocks committed run | `calibrated: false`, committed | `TemplateError` | `runner_spec.rb` |

---

# Phase 4 — Art generation (in depth) — `L`

Ordered so cheap, high-leverage fixes precede the expensive research steps.

## 4.1 Fix C1 prompt-synthesis defects (original §3.0–§3.1, feedback item 4) — `S`

**Goal.** Two category errors in the synthesis prompt: (a) `mood` (an arrangement measurement) is
used as a content instruction; (b) the template says "lead with the subject from Content Type"
when `content_type` carries no subject.

**Change.**
- **4.1a** — rewrite C1 step 2 to palette/contrast only; add `mood` to the do-not-specify list for
  composition density/energy. `bold_active` must not translate to "make the picture dense."
- **4.1b** — remove the impossible "lead with the subject matter from Content Type" instruction;
  either drop the subject slot (until 4.3) or, once 4.3 exists, feed an explicit subject.

**Files.** `knowledge_base/prompts/c1_generation_prompt_synthesis.md`, `app/steps/track_c/generate_art.rb`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 4.1.1 | negative: no mood-as-energy | `mood: bold_active` | rendered prompt contains no composition-density/energy language derived from mood | `coverage_spec.rb` |
| 4.1.2 | regression: frame_form still absent | prompt build | no `frame_form` interpolation (prior fix intact) | `coverage_spec.rb` |
| 4.1.3 | regression: color_role is saturation-only | `color_role` present | prompt has no geometry/layout derived from color role | `coverage_spec.rb` |

## 4.2 Batch variation axis (original §3a / feedback item 3a) — `M`

**Goal.** C1 synthesizes one prompt, `adapter.generate(prompt:, n: want)` rolls it N times → ten
copies of one picture. Give the C2 merit gate real alternatives.

**Change.**
- `PromptSynthesisSchema` returns an **array** of variants. Each variant declares one
  `variation_axis` (`subject_focus | composition | palette_emphasis | rendering_density`); no two
  variants may declare the same value on that axis.
- `GenerateArt` rejects the result if variant count < batch size or variation values repeat.
- Persist `variation_axis` to `step_log`.

**Files.** `app/llm/schemas/track_c/prompt_synthesis_schema.rb`, `app/steps/track_c/generate_art.rb`,
`knowledge_base/prompts/c1_generation_prompt_synthesis.md`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 4.2.1 | happy | synthesis returns N variants, distinct axes | C1 generates N images from N prompts | `steps_spec.rb` |
| 4.2.2 | negative: too few variants | variants < batch size | C1 fails / escalates | `steps_spec.rb` |
| 4.2.3 | negative: repeated axis value | two variants share `variation_axis` value | C1 fails | `steps_spec.rb` |
| 4.2.4 | regression: single-prompt path (non-variant) still works when batch=1 | batch 1 | one variant, no rejection | `steps_spec.rb` |

## 4.3 `A_subject` — subject research step (original §3.1) — `L`

**Goal.** Source subjects from real listings instead of inventing them.

**Change.** New Track A step `A_subject` (runs after A1, before the style-level lock):
1. 8+ independent shops, 3–4 image cap/shop, close-up/product-only, real search URLs.
2. Describe each image with a vision model **without naming the style**: "describe literally what
   is depicted — concrete subject only, no mood/color/composition."
3. Cluster into subject categories; keep only those recurring across **3+ shops**; log rejects
   with reason + count.
4. Persist `subject_research: { shops_sampled, recurring_subjects, rejected_subjects }` to the spec.

**Files.** new `app/steps/track_a/subject_research.rb` + `app/llm/schemas/track_a/subject_research_schema.rb`
+ prompt; `StyleSpecWriter`; conductor `STYLE_ORDER`; Track A sequence.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 4.3.1 | negative: no search calls | step returns an answer with 0 search calls | raises (reuse the no-search-raises check) | `spec/steps/track_a/` |
| 4.3.2 | negative: below-threshold subject promoted | subject across 2 shops | not in `recurring_subjects`; present in `rejected_subjects` with reason | `spec/steps/track_a/` |
| 4.3.3 | boundary: exactly 3 shops | subject across 3 shops | qualifies as `recurring_subject` | `spec/steps/track_a/` |
| 4.3.4 | negative: style name leaks into vision prompt | inspect built prompt | style name absent from the describe instruction | `spec/steps/track_a/` |
| 4.3.5 | happy: persistence | step ok | `subject_research` written to spec YAML | `spec/knowledge_base/` |

## 4.4 `A_scene` — scene-pattern research step (original §3.2) — `L`

**Goal.** Source composition/light/temporal structure, not just subjects.

**Change.** New Track A step `A_scene` (after/alongside `A_subject`, same retrieval pool):
1. Same retrieval discipline (8+ shops, 3–4 cap, close-ups).
2. Vision prompt asks for a **narrative** (one coherent moment; implied action; light relationship
   — brightest point vs. rest; what draws the eye first), not an attribute inventory.
3. Cluster at the *whole-narrative* level; 3+ shop threshold; log rejects.
4. Output `scene_patterns` with `narrative_structure` / `light_logic` / `temporal_quality`
   (abstracted, no specific subject/setting).
5. Two-pass agreement: re-describe 3 images with a second vision pass; flag `low_confidence: true`
   on substantial divergence.
6. Persist `scene_research: { shops_sampled, scene_patterns, rejected_patterns }`.

**Files.** new `app/steps/track_a/scene_research.rb` + schema + prompt; `StyleSpecWriter`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 4.4.1 | negative: 0 search calls | — | raises | `spec/steps/track_a/` |
| 4.4.2 | negative: pattern below 3 shops | pattern across 2 shops | in `rejected_patterns` | `spec/steps/track_a/` |
| 4.4.3 | boundary: exactly 3 shops | — | qualifies | `spec/steps/track_a/` |
| 4.4.4 | negative: second pass diverges | two-pass disagreement | `low_confidence: true` set | `spec/steps/track_a/` |
| 4.4.5 | happy: persistence | step ok | `scene_research` written | `spec/knowledge_base/` |

## 4.5 Rewire synthesis — code-level selection + template rewrite (original §3.3) — `L`

**Goal.** Make 4.3/4.4 output actually reach the generator without the "blend everything" failure.

**Change.**
1. **Selection in code.** Select exactly one `recurring_subject` + one `scene_pattern` in
   application code (round-robin or weighted by `recurs_across_shops`) *before* the synthesis call;
   pass only the chosen values, never the full list.
2. **Rewrite `c1_generation_prompt_synthesis.md`** per original §3.3: MUST-PRESERVE (narrative
   shape, light logic, temporal quality, chosen subject) vs MUST-INVENT-FRESH (setting, composition,
   secondary elements); keep `content_type` (density) + `color_role` (saturation only) + room-shape
   constraint; apply 4.1a (no mood-as-content). Fix the worked example's mood leak — the output
   must not contain "bold, alive energy."
3. **Batch variation** via draw-without-replacement across subjects × patterns (N distinct pairs).

**Files.** `app/steps/track_c/generate_art.rb`, a small selection service (or inline),
`knowledge_base/prompts/c1_generation_prompt_synthesis.md`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 4.5.1 | negative: list never shown | selection has N subjects | synthesis call receives exactly one subject string + one pattern's 3 fields | `spec/steps/track_c/` |
| 4.5.2 | happy: batch variation | 3 subjects × 2 patterns, batch 6 | 6 distinct (subject, pattern) pairs | `spec/steps/track_c/` |
| 4.5.3 | regression: no mood-as-energy in output | `mood` present | rendered prompt contains no "bold/calm energy" phrase | `coverage_spec.rb` |
| 4.5.4 | negative: copyrighted/inspired language forbidden | — | prompt contract forbids "similar to"/"inspired by"/named artists | `coverage_spec.rb` |

## 4.6 Execution-fidelity (conformance) check + fix ImageQa reference gap (original §3.4) — `M`

**Change.**
- **4.6a** — conformance check per candidate: vision model + `axis_contributions` → "contains the
  specified subject? a single focal light with everything else receding?"; drop on "no", log why;
  all-fail → surface as a batch failure, don't silently shrink.
- **4.6b** — `ImageQa#reference_urls` reads `@run.dossier_data["A1"]["curated_images"]`, which is
  never written. Populate it from A1's step result in the conductor.

**Files.** `app/agents/image_qa.rb`, `app/agents/conductor.rb` (populate dossier_data).

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 4.6.1 | negative: wrong-subject image | candidate lacking the specified subject | conformance flags it | `other_agents_spec.rb` |
| 4.6.2 | happy: correct candidate | subject + focal light present | passes | `other_agents_spec.rb` |
| 4.6.3 | negative: all candidates fail | entire batch fails | surfaced as batch failure, not silently shrunk | `other_agents_spec.rb` |
| 4.6.4 | regression: reference set populated | A1 completed | `dossier_data["A1"]["curated_images"]` non-empty; ImageQa receives it | `other_agents_spec.rb` |

## 4.7 C2 merit gate (original §3.5, feedback item 3) — `M`

**Change.**
- Log the human's pick: record the chosen candidate's `subject`/`pattern_id` (from
  `axis_contributions`) on the piece, joinable to sales later.
- Keep C2 two-stage (finalists → chosen).

**Files.** `app/steps/track_c/cull_to_finalists.rb`, `PieceRecord` fields `chosen_subject`/`chosen_pattern`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 4.7.1 | happy | human chooses candidate with known axis_contributions | piece records `chosen_subject`/`chosen_pattern` | `spec/steps/track_c/` |
| 4.7.2 | regression: two-stage intact | finalists then chosen | both stages still required | `steps_spec.rb` |

---

# Phase 5 — Listing recovery (original §8) — `M`

**Change.**
1. One-retry-with-feedback in `Steps::Base` for `:llm` steps (append validator message, cap at one,
   log both attempts).
2. P3_3: compute `first_six_words` in code.
3. P3_6: `fail_step` on blank `%{sizes}`/`%{dimensions}`.
4. P3_5: taxonomy 0-nodes = infrastructure failure (not retryable).

**Files.** `app/steps/base.rb`, `app/steps/phase3/{draft_title,write_description,fill_attributes}.rb`.

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 5.1 | negative: validation failure triggers one retry | inject failing title | retry fires exactly once, both attempts logged | `steps_spec.rb` |
| 5.2 | negative: retry also fails | validator still fails | escalates with both attempts + validator message | `steps_spec.rb` |
| 5.3 | regression: first-six mismatch impossible | title returned | `first_six_words` computed in code, no self-report mismatch | `steps_spec.rb` |
| 5.4 | negative: blank sizes | sizes/dimensions blank | P3_6 `fail_step`, no placeholder copy | `steps_spec.rb` |
| 5.5 | negative: taxonomy 0 nodes | fetch returns empty | P3_5 treated as infra failure | `steps_spec.rb` |

---

# Phase 6 — Print-resolution ceiling (original §5) — `S`

**Change.** Record generator max output resolution (config, `volatility: live`); compute
`max_inches = max_px / 300` per dimension; block oversized variants.

**Files.** config value + the size-setting step (`app/steps/phase3/fill_attributes.rb`).

**Test cases.**

| # | Scenario | Given | Then | Target |
|---|---|---|---|---|
| 6.1 | negative: oversized size | size needs more px than generator max at 300 DPI | blocked | `steps_spec.rb` |
| 6.2 | boundary: exactly at ceiling | size == max_px/300 | passes | `steps_spec.rb` |
| 6.3 | regression: 24×36″ example | generator max known | 7200×10800 requirement respected | `steps_spec.rb` |

---

# Ordering & dependencies

```
0 (rewind)  ─┐
1 (name)     ┼─ independent, parallel
3 (placement)┘
2 (production_model)   — after 1
4.1, 4.2, 4.6b         — cheap; after 1 (touch C1)
4.3, 4.4               — after 1 (need correct style_name for queries)
4.5                    — after 4.3 + 4.4
4.6a                   — after 4.5 (needs axis_contributions)
4.7                    — after 4.2 (needs real batch variation)
5, 6                   — independent, any time
```

**Deferred / excluded:** §4 (AI disclosure) — removed; §6 (frame rendering) — excluded per product
decision; §3.5 (feedback loop) — wait until there are ≥3 published pieces with sales data.

**Do not re-approve `run_20260907_17b8`.** Its KB SHA is stale once any of the above lands, and its
`P2_6`/`C2`/`A3` gates passed in non-approvable states.
