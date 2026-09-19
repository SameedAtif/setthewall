# Phase 3 — Feedback Interpretation, Summaries, Re-run

## Task description

Add the natural-language layer and re-run/staleness mechanics: `Llm::CellSummarizer` (prose
summary per cell), `Llm::FeedbackInterpreter` (+ schema, constrained by existing decision rules),
`Workflow::CellRerunner` (re-run a cell and stale its downstream cells), and
`Workflow::GateApplier` (apply a confirmed decision and resume). Service-level only — no UI.

## Goal

Let each cell render as human prose and let plain-English feedback become a validated structured
step decision, with downstream invalidation — all while `DecisionRules` remains the final
authority on what decisions are legal.

## Non-goals

- No controllers, views, Stimulus, or Turbo Streams.
- No change to step/agent/decision behavior.
- No commit/publish changes.
- The interpreter must not bypass, weaken, or second-guess `DecisionRules`.

## Deliverables

- `Llm::CellSummarizer` with prompt + deterministic fallback.
- `Llm::FeedbackInterpreter` + `Schemas::FeedbackInterpretationSchema`.
- `Workflow::CellRerunner`.
- `Workflow::GateApplier`.
- `Context::Assembler` taint rule extended to `stale`.
- Service specs with stubbed `RubyLLM`.

## Strategy

### CellSummarizer

- Input: `step_id`, structured output/data, message.
- Output: a 2–5 sentence paragraph; persist to `run_step.summary` at step completion.
- Fall back to the existing `Dossier::Builder` narrative (or a deterministic renderer) if the LLM
  call fails or returns nothing usable.
- Never block step completion on summarization failure.

### FeedbackInterpreter

- Input: cell context (step, summary, gate question, output) + user prose.
- Output schema: `{ intent, notes, edits, reason, override_reason, acceptance_note }`, where
  `intent` is one of the legal dispositions for the step's verdict.
- Constrain candidates with `DecisionRules.legal_dispositions`; reject or ask for clarification
  when the prose maps to an illegal disposition.
- Split into `interpret` (returns a preview, writes a `StepFeedback` with `applied: false`) and
  `apply` (commits the decision). No mutation happens during `interpret`.

### CellRerunner

- Given a cell and an applied decision: clear step side effects, reset the cell to `pending`,
  mark all downstream cells `stale`, and truncate the mirrored `step_results` from that step
  onward.
- Then invoke `CellRunner` for the re-run.
- Stale cells remain visible until the user runs them.

### GateApplier

- Validate the interpreted decision via `DecisionRules.validate_disposition!`.
- Close the `HumanGate` with the correct status/verdict/reviewer kind, update the `RunStep`,
  record the applied `StepFeedback`, then advance (`CellRunner`) or mark downstream stale
  (`CellRerunner`) depending on the disposition (approve/edit vs reject/redo/rewind).

### Taint rule

- Extend `Context::Assembler#tainted?` so a `stale` cell contributes no values downstream,
  matching the existing `failed` / `rewind` / `abandon` behavior.

## Validation

- Summarizer specs: happy path plus fallback when RubyLLM fails/returns blank.
- Interpreter specs: intent mapping, legal/illegal disposition handling, preview vs apply
  (no mutation on interpret).
- Rerunner specs: downstream cells become `stale`, `step_results` truncated correctly.
- GateApplier specs: gate closed correctly; invalid dispositions raise.
- Assembler spec: stale values are tainted and absent downstream.
- Stub `RubyLLM` everywhere; no live LLM calls in tests.

## Definition of done

- All four services and the schema exist with specs.
- Summaries persist per cell; interpreter never mutates before confirmation.
- Re-running a middle cell reliably stales all downstream cells.
- Full suite passes; `rubocop` is clean.
