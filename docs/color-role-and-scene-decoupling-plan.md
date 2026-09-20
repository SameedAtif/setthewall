# Color Role & Scene Decoupling — Implementation Plan

## Implementation status

**Proposed — not implemented.** This document captures a design discussion about where
`color_role` should come from and whether the scene should influence art generation at all. It
records the decisions reached, the ripple effects, and the open questions that still need an
owner's call. Nothing here has been built.

## Purpose and scope

This plan changes **where the `color_role` axis is derived** and **what the scene is allowed to
influence in Track C**. Today `color_role` is the one axis that bridges the two sides of the
pipeline — it reads the *room* (Track B, step B6) and tells the *art* how to relate to it. This
plan proposes moving it out of Track B and deriving it from the reference art in A1b, which severs
the room→art colour link and reassigns the remaining scene→generation coupling (line orientation)
to Phase 2 arrangement.

The scope is intentionally narrow: **axis ownership, step membership, and prompt wiring.** It is
not a rewrite of Track A/B/C semantics beyond that.

### What this is

- A **re-homing of `color_role`** from a human-gated scene axis (B6) to a **style-level
  observation** derived at A1b from the reference candidates.
- A **new style-level `palette_character` axis** (derived at A1b from the same candidates) that
  describes the *art's* colour character — the vocabulary generation and QA need. `color_role`
  stays the room-function vocabulary for Phase 2.
- A **retirement of B6** (`Steps::TrackB::ColorRole`) and its human strategic gate.
- A **decoupling of art generation from the room**: C1 stops taking a room-derived colour role
  and stops taking the `room_shape` line-orientation hint.
- A **reassignment of line orientation / space tips to Phase 2 arrangement** (where the
  arrangement vocabulary already lives).
- Supporting spec/schema/registry/sequencer/test changes to make the above coherent.

### What this is not

- **Not a change to the reference-set semantics of A1.** A1 still builds the curated set and its
  mood reconciliation; A1b still distils the essence — it simply also carries `color_role`.
- **Not a change to B0–B5.** Wall condition, furniture weight, room type, room shape and space
  math are untouched; they continue to drive placement/framing and (optionally) one composition
  hint.
- **Not a change to the compositor, Etsy adapter, or Phase 3 copy sources** beyond the source of
  `piece.color_role`.
- **Not a product decision about whether art should be room-adaptive** — that is the core open
  question below; this doc argues for one side but flags it as a decision.

### Assumptions

- A1b already performs a vision pass over A1's curated images, so per-image classification is a
  natural extension of an existing call.
- `piece.color_role` remains a column and continues to be the interface to Phase 2 mat intensity
  and Phase 3 copy — only its *source* changes. Generation and `ImageQa` additionally consume the
  new `palette_character` (read from the style spec/essence).
- Existing runs are not migrated; changes apply to new runs and to re-runs of A1b/A5/B7/C1.

## Background — the two problems

### 1. `color_role` is a human-gated, room-derived axis mixed into art generation

- In the knowledge base, `color_role` is a **room-relationship** axis: `color_role.yml` frames each
  value as the piece's job relative to the colours already in the room (`color_burst` = the room's
  one splash; `unifier` = tie scattered accents; `saturator` = reinforce the room's theme;
  `line_only` = remove colour tension; `accent_highlighter` = bring out one existing accent).
- It is assigned at **B6** from a vision read of the scene photo, and the KB designates the
  `minimalist_modern → line_only` default as "the one genuinely strategic call in B6", i.e. a
  human decision. In practice this forces a pause for every run and is a poor fit for a neutral
  tonal style (forcing `line_only` injects "no colour" against a warm-neutral reference palette).
- Meanwhile `generation_prompt_template.yml` maps `color_role` to a **saturation/colour
  instruction** in the image prompt (`%{color_treatment}`). So a *room-relationship* axis is used
  as the *art's* colour instruction — the mismatch that produced the monotone output.

### 2. Line orientation / space tips are a Phase 2 concern misfiled as generation

- `space_tips.yml` is sourced from **Phase 2 §2.5a** ("Space tips, line orientation and content"),
  yet **nothing in Phase 2 reads it**. The only consumer is C1, via
  `generation_prompt_template.yml`'s `space_tips_modifier` and the hardcoded
  `GenerateArt#room_shape_constraint`.
- `arrangement_forms.yml` (Phase 2 §2.7) already owns orientation/placement — `gallery_style`
  ("one long, neat row — horizontal or vertical"), `stair_stepping` ("align center points
  diagonally"), `combination_alignment` (rows). The space-shaping effect is achievable by
  *arrangement*, not by the art's content.
- `space_tips.yml` mixes two kinds of technique: line orientation (`narrow → horizontal lines`,
  `low_ceilinged → vertical lines`) — arguably arrangement; and content (`small_closed_in → a
  landscape with a distant vista`) — genuinely art, but a scene→content coupling that does not fit
  an abstract style.
- The coupling is demonstrably fragile: `GenerateArt#room_shape_constraint` is **inverted** versus
  the rule file (`narrow → vertical`, `low_ceilinged → horizontal`) and uses "open composition"
  for `small_closed_in` where the rule says "distant vista". The code mirrored a stale prompt, not
  the rule file (`space_tips.yml:9-17`).

### 3. There is no art-facing colour vocabulary

- `color_role` is the only colour axis, and it is a room-function taxonomy. Nothing in the pipeline
  describes the *artwork's* colour character — the very thing the generator must reproduce. The
  nearest thing is `reference_essence.palette`, which is a free-text sentence, not a scored value.
- Deriving `color_role` from the reference images (Decision 2) papers over this: it asks a
  room-function label to stand in for an art property. The clean fix is a second, purpose-built
  style-level field — **`palette_character`** — alongside `palette`, that C1 and `ImageQa` consume.

## Mental model

The pipeline has two independent inputs — the **style** (Track A) and the **room** (Track B) — and
one output, the art + its presentation. This plan moves the pipeline toward:

- **Art = style.** Track A (+A1b) fully determines what the artwork is: mood, content type, frame
  form, and the typed reference essence (medium, palette, surface treatment, motif vocabulary, and
  now colour role). Track C generates from that, independent of the room.
- **Scene = staging.** Track B observes the room; Phase 2 uses it to place, frame, mat and
  composite the art. The scene stops influencing the art's colours and content.
- **Arrangement owns orientation.** The "space tips / line orientation" technique is realized by
  Phase 2 arrangement forms, not by the generator.

This is the "art = style, scene = staging" model. The alternative ("style base + room modulation")
is captured as an open question.

## Decisions reached in discussion

1. **`color_role` is an observation, not a human decision.** It should be derived from the
   reference set, not arbitrated by an operator.
2. **Derive it at A1b from the A1 candidates by mode.** A1b classifies each candidate image's
   colour role; the role carried by the **most candidates wins** (a vote, not a hand-pick). A
   **tie is a human decision** at the A1b gate, shown with a per-role tally and examples.
3. **B6 is retired** as a result; the role becomes style-level rather than a scene axis.
4. **Line orientation / space tips leave generation.** They belong to Phase 2 arrangement; C1
   should not take a `room_shape` composition hint.
5. **No fallback and no hardcoding.** The role is derived from data for every style; the pipeline
   must not special-case any content type.
6. **Add a separate `palette_character` field for the art.** A new style-level, **open-ended**
   field, derived as free text at A1b from the same candidate images, gives generation and QA a
   description of the art's colour (see "New axis: `palette_character`"). It is not an enum and
   `color_role` is not overloaded to carry it.
7. **Generation's colour instruction comes from `palette_character`, not `color_role`.** This
   resolves the original room-vs-palette mismatch: an art axis describes the art's colour, and
   `color_role` only feeds Phase 2 mat/framing.

## Resolved decisions (owner's call)

1. **Model: "art = style, scene = staging."** The scene does not modulate the art. **B6 is removed
   entirely** — not kept as an advisory check.
2. **Tie-breaker is human.** When the per-image vote has no strict majority, A1b flags the role as
   ambiguous and the A1b review gate presents the human with each candidate role, its tally, and
   **examples** (the images that carried it) so they can choose. The A1b gate is the decision point
   — no automated fallback precedence.
3. **Values live in `reference_essence`** — `reference_essence.color_role` and
   `reference_essence.palette_character`, alongside `palette`, not a separate top-level field.
4. **`palette_character` is open-ended and derived, not a preset enum.** A1b writes a free-text
   description of the art's colour character straight from the reference images. The pipeline must
   not bound it to a fixed list or to any value already in the codebase.

## New axis: `palette_character`

A **style-level, open-ended** field, derived from the reference candidates at A1b, describing the
artwork's colour character as free text. It is deliberately separate from the arrangement book's
enumerated, room-function `color_role`.

### Why a new axis instead of extending `color_role`

`color_role`'s five values are room-function categories with a source citation. Adding art-colour
values there would (a) mix two different questions in one axis, (b) break the KB's cite-verbatim
discipline, and (c) require editing ~8 enum sites for the wrong vocabulary. A distinct axis can be
authored and evolved on its own.

### Shape: open-ended, not an enum

Unlike `color_role` (five cited room-function values), `palette_character` is a **free-text,
derived description** of the artwork's colour character — e.g. "a warm-neutral tonal range of bone,
oatmeal and soft grey with no saturated hue", or "muted sage and blush pastels", or "bold
high-chroma primaries". It is deliberately unbounded so the pipeline never has to force a style
into a value that doesn't fit it, and it is derived from the reference images rather than chosen
from a list in code.

### Derivation

1. The A1b vision call writes the `palette_character` description from the reference images (and
   records which images informed it), alongside `palette`.
2. Stored as `reference_essence.palette_character`; A5 writes it into the spec with the rest of the
   essence.
3. Because it is free text there is no mode/tie-break for it — the vote and the human tie-breaker
   apply only to the enumerated `color_role`.

### Consumption

- **C1 generation**: the `palette_character` text drives the art's colour clause, replacing the
  `color_role`-derived `%{color_treatment}`. Because it is free text it is inserted directly (no
  enum→phrase mapping) — e.g. "a warm-neutral tonal range with no saturated hue; build depth from
  value and texture, not chroma".
- **ImageQa**: a `palette_character` conformance check alongside palette/surface/motif.
- **Phase 2/3**: unchanged; they keep using `color_role` (mat intensity) and the essence palette.

## Data model changes

- **`reference_essence` gains `color_role` (+ `color_role_tally`) and `palette_character`
  (+ `palette_character_tally`).** Produced by A1b, written into the style spec by A5, read by
  `Context::Assembler` / `PieceBuilder`.
- **`StyleSpec::SCENE_AXES` drops `color_role`** (6 → 5 axes). `ALLOWED[:color_role]` is retained
  for validating the style-level value.
- **`SceneSpec#validate!`** stops expecting `color_role` in a scene's axes.
- **`PieceRecord#apply_spec!`** reads `color_role` from the style spec/essence instead of
  `scene.color_role`; the `piece.color_role` column and all downstream consumers are unchanged.
- **`version-0.0.1.yml` (and any other spec)**: remove `scenes.*.axes.color_role`; the new value
  appears under the style-level essence once A1b/A5 re-run.

## Step changes

### A1b — `Steps::TrackA::DistillReferenceEssence`

- **Schema (`ReferenceEssenceSchema`)**: add per-image `color_role` (the 5-value enum) **and**
  `palette_character` (the new axis), aligned to the input image order so the votes are traceable;
  keep `palette`/`surface_treatment`/`motif_vocabulary`/`medium`/`styling`/`outlier_indices`.
- **Step (`perform`)**: after the vision call, compute the mode for **both** fields across
  non-outlier images, apply the tie-breakers (Open Q2 and the `palette_character` section), and
  store `color_role` + `color_role_tally` and `palette_character` + `palette_character_tally`.
- **Prompt (`a1b_reference_essence.md`)**: instruct the model to tag each image's `color_role`
  (definitions from `color_role.yml`) and `palette_character` (the new taxonomy), based only on the
  image.

### B6 — `Steps::TrackB::ColorRole` (retired)

- Remove the step class, its registry entry, its `decision_rules.yml` entry, its `TIERS` entry,
  its slot in `RunSequencer::SCENE_STEPS` / the style orders and `Conductor::STYLE_ORDER`, the
  `Context::Assembler` `B6` case, the `AxisQa` B6 branch, the `_color_role` view and the
  `RunStepsController#color_role` action.
- `color_role_observation.yml` is retired (its observation guidance moves into the A1b prompt).

### B7 — `Steps::TrackB::LockSceneEntry`

- Locks **5** scene axes instead of 6; update the confirmation text and `SceneSpec` validation.

### C1 — `Steps::TrackC::GenerateArt`

- **Remove the room-shape / line-orientation clause**: delete `room_shape_constraint`, the
  `%{line_constraint}` placeholder and the `room_shape` axis contribution. (Space tips move to
  Phase 2 arrangement.)
- **Colour clause now comes from `palette_character`**: replace the `color_role`-derived
  `%{color_treatment}` with a `palette_character` directive from `generation_prompt_template.yml`.
  `color_role` no longer feeds generation at all.

### Phase 2

- **Own arrangement orientation.** Wire `space_tips.yml`/`arrangement_forms.yml` into the
  placement branch (`P2_1`) / arrangement step so line orientation and space tips are applied at
  hanging time, not generation time.
- **Reword `color_function_check` (P2_4b).** It currently checks whether the piece fulfils its
  colour *function in the room*; with a style-derived role that premise is gone. Either reword it
  to an art-intensity/framing check or fold its `mat_intensity` lookup into `P2_4`.

## Wiring and services to change

- `app/services/context/assembler.rb` — drop the `B6` derived case and `scene_axis("B6", "color_role")`;
  source `color_role` from the essence.
- `app/steps/track_a/distill_reference_essence.rb` + `app/llm/schemas/track_a/reference_essence_schema.rb`
  — per-image role + mode.
- `app/knowledge_base/style_spec.rb` + `style_spec_writer.rb` — axis set, essence persistence.
- `app/models/piece_record.rb` — `apply_spec!` source.
- `app/services/workflow/run_sequencer.rb` + `app/agents/conductor.rb` — order/`SCENE_STEPS`.
- `config/step_registry.yml`, `knowledge_base/rules/decision_rules.yml`,
  `app/services/workflow/decision_rules.rb` — remove B6.
- `knowledge_base/prompts/c1_image_prompt.md`, `c1_generation_prompt_synthesis_scene.md`,
  `c1_generation_prompt_synthesis.md` — drop `%{line_constraint}` / `room_shape`.
- `knowledge_base/rules/generation_prompt_template.yml` — drop the `space_tips_modifier`; retire
  the `color_role` generation directives (the role stays for Phase 2 mat/framing via
  `color_role.yml`). `palette_character` needs no directives — its free text is inserted directly.
- Views/controllers — remove `_color_role.html.erb`, `_decision`'s color-role branch, and the
  `color_role` action.

## Ripple analysis

### B-series

- **B0–B5 untouched.** They still observe the room and feed placement/framing.
- **B6 removed.** The scene loses its colour identity; the room no longer informs the art's colour.
- **B7** locks 5 axes; the locked scene becomes a *stage*, not a source of art direction.
- The scene's remaining influence on generation is reduced to nothing (once line orientation also
  moves out). Net: Track B becomes a presentation track.

### C-series

- **C1 becomes fully style-driven** — zero room inputs. Conceptually it could run without a scene;
  the scene becomes a Phase 2 concern.
- **C2** (cull/chosen) unaffected.
- **P2_4b** loses its premise (see Step changes).
- **Phase 3 copy/attributes** (`color_role_confirmed → primary_color`) now reflect a style property,
  which is arguably more correct; consider sourcing it from the essence palette instead.

### Product implication

Under this model, a **style** yields a piece (or a set) and a **scene** is one of several
stagings — closer to how POD listings work (one artwork, multiple mockups) than "generate a unique
piece per room". Under the current model every scene could yield a different, room-adapted piece.
Deciding which product you are building is Open Q1.

## Testing

- **A1b**: classify + vote for **both** `color_role` and `palette_character`; strict-majority,
  close-up tie-breaker, palette fallback; outliers excluded from the vote.
- **Assembler/PieceBuilder**: C1's context carries the essence-sourced `color_role` and
  `palette_character`; no B6 dependency.
- **Sequencer/registry/decision-rules**: B6 absent from orders, coverage counts, tiers.
- **C1**: prompt has no `%{line_constraint}`; the colour clause comes from `palette_character`.
- **ImageQa**: `palette_character` conformance check.
- **Phase 2**: arrangement applies the space tip; `color_function_check` reworded.
- **Specs to delete/rewrite**: `spec/steps/track_b_spec.rb` (ColorRole block),
  `spec/system/notebook_spec.rb` (B6 radio test), `spec/requests/run_steps_spec.rb` (color_role
  action), `spec/agents/*` (AxisQa B6), registry/sequencer count assertions.
- Keep the suite green; `rubocop` + `erb_lint` clean.

## Phases

1. **Phase 1 — Derive `color_role` and `palette_character` at A1b.** Schema (per-image values),
   votes + tie-breakers, essence fields, prompt; unit tests. No behavior removed yet.
2. **Phase 2 — Move both to the style spec.** `SCENE_AXES`, `apply_spec!`, spec writer,
   `Context::Assembler`; migrate `version-0.0.1.yml`; tests.
3. **Phase 3 — Retire B6.** Remove step, registry, decision rules, tier, order entries, view,
   controller action, AxisQa branch; update counts and specs.
4. **Phase 4 — Decouple C1 from the room.** Remove `room_shape`/line-orientation from C1's prompts
   and `GenerateArt`; swap the colour clause from `color_role` to `palette_character`.
5. **Phase 5 — Phase 2 arrangement ownership.** Wire space tips/arrangement forms into placement;
   reword `color_function_check`.

## Out of scope

- Rebuilding Phase 2 arrangement UI or expanding `arrangement_forms`.
- Migrating existing runs' `color_role` values (new runs only; old specs re-lock on re-run).
- Any provider/model change for generation or vision.
- The `content_type` taxonomy (`minimalist_modern` conflation) — tracked separately in
  `docs/c1-art-quality-plan.md`.
