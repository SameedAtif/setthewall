# C1 Art-Quality Plan — reference-faithful generation

**Status:** FINAL (decisions resolved; not yet implemented)
**Scope:** Track C step C1 (`Steps::TrackC::GenerateArt`) and its inputs (A1/A1b essence, A6 subjects)
**Last updated:** 2026-09-20

## Problem

C1 batches come out monotone and off-vibe relative to the curated reference set:

1. **Monotone / no tonal range** — `color_role: line_only` (confirmed at B6 for run 15) maps to
   *"black, white, grey — no colour; lines and pattern carry the piece"* in
   `knowledge_base/rules/generation_prompt_template.yml`, which contradicts the reference set's
   warm-neutral palette and suppresses tonal range.
2. **Vibe / style drift** — the first paragraph of the image prompt (`%{scene}`) is invented by a
   text LLM with no visibility into the reference set, and the second (`%{reference_essence}`) is a
   text-inferred summary from A1's search snippets, not a visual read of the images. The actual
   reference images reach only the image-gen adapter.

## Architecture today (as implemented)

- `%{scene}` — `SubjectSceneSelector.pairs(spec, want)` picks one (subject, pattern) pair per
  candidate from `subject_research` (A6) × `scene_research` (A7). `build_synthesis_prompt` renders
  `knowledge_base/prompts/c1_generation_prompt_synthesis_scene.md`; Qwen (`Pipeline::TEXT_MODEL`) is
  called with `Schemas::TrackC::PromptSynthesisSchema` and returns `scene_description`. Text-only;
  reference-blind; the meta-prompt says `MUST INVENT FRESH`.
- `%{reference_essence}` — produced earlier by A1 (`Steps::TrackA::BuildReferenceSet`,
  `mechanism: :llm_text`) as free-text `shared_qualities` + `dominant_mood`. `Context::Assembler#reference_essence`
  reads them from `step_results`; `reference_essence_clause` string-templates a sentence into the
  image prompt. No LLM call at prompt-assembly time; styling and art traits are mixed.
- `c1_image_prompt.md` — concatenates `%{scene}` + `%{reference_essence}` + a footer built from the
  locked axes (`color_role` → colour treatment, `mood` → palette, `room_shape` → line constraint,
  rule-file negative clause).
- Reference images — passed only to the image adapter as `style_reference:`; currently the first N
  `closeup`s (`Context::Assembler#style_reference_images`, `C1_STYLE_REFERENCE_LIMIT`, default 4).

## Acceptance criteria (numeric)

1. Palette / surface / motif conformance to the reference set — scored vs the typed essence.
2. Composition diversity within a batch — **≥ 20–30%** spread across descriptor fields (see 4.2).
3. No 1:1 replica — per-image `max_similarity_to_any_single_reference` **≤ 70–80%**. Originality
   beyond "not a replica" is explicitly out of scope ("if it works, don't fix it").
4. Tonal range present (not monotone).

Measured by an extended `ImageQa` (gate) plus a human 1–5 "resembles the reference set" rating, over
batches of 6, one lever changed at a time. The existing 566-example suite stays green; rubocop and
erb_lint stay clean.

## Decisions (resolved)

1. **A1 vision → separate step `A1b` ("Distill reference essence").** It gets its own gate because
   the typed essence (especially `motif_vocabulary` and the diversity descriptors, 2.5) is a human
   review/pass. Fold-nothing: A1 stays curation; A1b is distillation.
2. **Typed essence lives in the style spec.** It is consumed by C1 generation and `ImageQa`, both of
   which read style-scoped data, so A1b writes it to the style spec and A5's lock carries it
   forward. (It is also present in `step_results` for provenance.)
3. **QA is a gate**, not advisory.
4. **Generic across all styles.** No style-specific code. The only per-style data is the reference
   essence and subject pool, both produced by the run.
5. **Subject curation now, as data.** Edit the current style's spec `subject_research` — no
   hardcoding in code. Build a generic curation step later only if it becomes a bottleneck.
6. **Do not hardcode `color_role`.** Remove the forced `minimalist_modern → line_only` override;
   B6 proposes from observation (essence-informed), human confirms at the gate.
7. **Thresholds:** `max_similarity_to_any_single_reference` ≤ 70–80%; batch diversity ≥ 20–30%.
8. **Latency matters, cost does not.** Prefer parallelism; no fixed budget, but any new vision stage
   must run concurrently where possible.

---

## Stage 0 — Safe wording + data fixes (no new plumbing)

| # | Change | Where |
|---|---|---|
| 0.1 | Reword `line_only` → monochrome **tonal** ("full value range; rely on tone, texture, light — not lines") | `knowledge_base/rules/generation_prompt_template.yml:38` |
| 0.2 | Add **two** clauses: (a) composition-variance — "vary the direction/position/presence of the tonal transition and any accent line; do not reproduce any single reference's split or seam placement"; (b) motif-tightening — "<approved motif vocabulary> only — no crosshatching, no tight coils, no texture types outside it" | `knowledge_base/prompts/c1_image_prompt.md` |
| 0.3 | Remove the forced `minimalist_modern → line_only` override; B6 proposes the role from observation, human confirms | `knowledge_base/rules/color_role_observation.yml`, `app/steps/track_b/color_role.rb` (`pauses_for_override?`) |
| 0.4 | Curate A6 subjects for this style by editing spec data (drop landscape / geometric / line-grid pairs) | style spec `subject_research` |

**Note — 0.1 and 0.3 are different fixes to the same symptom.** `0.1` changes the KB-wide *meaning*
of `line_only` (helps styles that legitimately use it). `0.3` stops this scene from being forced into
`line_only` at all: B6's observation was `color_burst`, which the default overrode. After 0.3, B6
proposes per style/scene and nothing is hardcoded.

Verify (Wave 1): tonal range present; composition varied; motif drift absent; no off-vibe subjects.
Risk: low. 0.1–0.2 are KB edits read at runtime (no restart). Motif wording in 0.2 is a stopgap; the
durable version is generated from `motif_vocabulary` in Stage 3.3.

## Stage 1 — Instrument before iterating (observability)

| # | Change | Where |
|---|---|---|
| 1.1 | Log a `prompt_version` (SHA of `c1_image_prompt.md` + `generation_prompt_template.yml` + synthesis template), plus typed essence + refs used | `GenerateArt#write_prompt_log` |
| 1.2 | Log the `SubjectSceneSelector` pairs + seed for reproducibility | `GenerateArt` |

Built **before** Wave 2 so batches are attributable. Risk: low.

## Stage 2 — Distill reference essence (new step A1b)

| # | Change | Where |
|---|---|---|
| 2.1 | New step **A1b**: vision call over A1's curated images producing typed fields `palette`, `surface_treatment`, `motif_vocabulary[]`, `medium`, `styling` (kept separate), each with `image_indices`; per-image `motif_tags` / `is_outlier`. Own gate. | new step + schema + prompt; registered in `RunSequencer`/`Conductor` order |
| 2.2 | Verify/curate `is_outlier` and `motif_vocabulary` at the A1b gate | A1b review pass |
| 2.3 | Write the typed essence into the **style spec** (carried through A5's lock) | `style_spec_writer.rb` / `style_spec.rb` |
| 2.4 | `reference_essence` reads the typed fields from the spec (removes the "ignore styling" patch; `styling` is its own field, unused for generation) | `Context::Assembler#reference_essence` |
| 2.5 | **Diversity descriptor set** — defined manually by whoever curates `motif_vocabulary`, in the same review pass (e.g. transition position/orientation, seam presence, motif region shape). Not automated for now; revisit if manual definition becomes a bottleneck across styles. | A1b review pass (data) |

**No fallback:** existing styles must re-run A1/A1b; a style without typed essence does not generate.
Verify: unit tests; a re-run of A1/A1b for this style shows typed fields on the spec. Risk: medium.

## Stage 3 — Ground the synthesis (the actual fix)

| # | Change | Where |
|---|---|---|
| 3.1 | Pass typed essence fields into `build_synthesis_prompt` | `GenerateArt:264` |
| 3.2 | Attach localized reference images to the **synthesis** call (vision), parallelized across candidates | `GenerateArt#run_candidate` |
| 3.3 | Replace `MUST INVENT FRESH` with bounded language: recombine documented palette/motif/surface only; vary composition/transition/position; forbid content outside `motif_vocabulary` | `knowledge_base/prompts/c1_generation_prompt_synthesis_scene.md:28` |
| 3.4 | Constrain `SubjectSceneSelector` to a reference-consistent subject subset (from spec data) | `Art::SubjectSceneSelector` + spec |
| 3.5 | Curated reference subset for the image call (drop `is_outlier`; mix closeups + in-situ) | `Context::Assembler#style_reference_images` / spec |

Verify (Wave 2): compare against **B1**. Risk: medium-high — this is where fidelity is won or lost.

## Stage 4 — Measure (QA gate + diversity)

| # | Change | Where |
|---|---|---|
| 4.1 | Extend `ImageConformanceSchema` + `ImageQa`: (a) set-level palette/motif/surface conformance vs typed essence; (b) **per-image `max_similarity_to_any_single_reference`** (anchoring detector, separate from set-level conformance); (c) constraint violations. **Gate.** | `app/agents/image_qa.rb`, `app/llm/schemas/qa/…` |
| 4.2 | Batch diversity = **spread across the manually-defined descriptor fields** extracted in the same vision call (see 2.5). No embeddings for now. | `ImageQa` |
| 4.3 | Write scores into the prompt log; gate C2 on pass | `ImageQa` + `StepExecution` |

Risk: medium. Without this, Stage 3's effect is not measurable.

## Stage 5 — Category fix (optional, only if needed)

| # | Change | Where |
|---|---|---|
| 5.1 | Add a **style-level palette** axis so palette isn't carried only by `color_role` (may be unnecessary once essence holds palette) | `KnowledgeBase::StyleSpec::STYLE_LEVEL_AXES` + writer + spec files |
| 5.2 | Refine the `content_type` taxonomy (`minimalist_modern` conflates tonal vs line art) or add a tonal/textured content type | `color_type*.yml`, schemas |

Note: 0.3 already removes the hardcoded override, so the generic behaviour lands in Stage 0; 5.2 is
only about the taxonomy's expressiveness.

---

## Test matrix

**Wave 1 — after Stage 0/1**
Hold constant: reference set, piece axes, `candidate_count = 6`.

| Batch | Lever |
|---|---|
| B0 | Baseline (current) |
| B1 | + Stage 0 wording (production-realistic) |
| B1c | + Stage 0 wording, **controlled** — the same subject/pattern pair pinned across all 6 candidates |

B1c exists because production varies the subject/pattern per candidate
(`SubjectSceneSelector.pairs`), so a diverse production batch can't tell you whether 0.2's
composition-variance clause worked or whether per-candidate subject variation did all the work. B1c
isolates it (mirrors the manual test method).

**Wave 2 — after Stage 2/3; measured against B1, not B0** (B0 still has the monotone bug)

| Batch | Lever |
|---|---|
| B2 | + typed essence in synthesis (3.1) |
| B3 | + synthesis vision (3.2) |
| B4 | + bounded invention (3.3) |
| B5 | + curated subjects / refs (3.4 / 3.5) |

Score each on the four acceptance criteria; stop when conformance and diversity pass and
`max_similarity` is under the cutoff.

## Sequencing / effort

1. **Now:** resolve nothing further — Stage 0 (S) + Stage 1 (S) → Wave 1 (B0/B1/B1c).
2. **Next:** Stage 2 (M) + 2.5 (data) → Stage 4 minimal (log + rubric) → Stage 3 (M/L) → Wave 2.
3. **Then:** Stage 4 full gate; Stage 5 only if needed.
4. Every stage: extend specs, keep 566 green, rubocop + erb_lint clean.
5. New vision stages (A1b, synthesis) must be parallelized to control latency.

## Out of scope

- Originality optimization beyond "not a 1:1 replica".
- Provider-level text/image weighting — only if Stage 3 proves insufficient.
- Switching the generation provider (e.g. Flux img2img) — fallback only, not planned.
- Fallback for styles without a typed essence — they must re-run A1/A1b.
