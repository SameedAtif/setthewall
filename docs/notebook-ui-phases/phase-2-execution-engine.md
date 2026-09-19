# Phase 2 — Execution Engine

## Task description

Extract the per-step execution path currently embedded in `Conductor#execute` into a shared
`Workflow::StepExecution` service. Add `Workflow::RunSequencer` (ordering + branches + locked-spec
skipping) and `Workflow::CellRunner` (run one cell / run until a gate / run all), and refactor the
`Conductor` to use `StepExecution`. Service-level only — no UI.

## Goal

Make single-step execution a first-class, testable service with behavior identical to the
conductor, and make "what runs next" a single source of truth. This is the engine the notebook
will drive in later phases.

## Non-goals

- No controllers, views, Stimulus, or Turbo Streams.
- No natural-language feedback, interpretation, or summarization.
- No change to step classes, prompts, schemas, QA agents, verdicts, dispositions, or
  `DecisionRules` behavior.
- No change to `CommitRunJob` or committed-mode replay.
- Not wired into any route or job yet.

## Deliverables

- `Workflow::StepExecution` service (execution + QA + verifier + gate/escalation recording).
- `Workflow::RunSequencer` service (full order, conditional branches, locked-spec skips,
  next-runnable computation).
- `Workflow::CellRunner` service (`run_next`, `run_until_gate`, `run_all`).
- `Conductor` refactored to delegate execution to `StepExecution`.
- Service specs for all three, plus a conductor/cell-runner parity spec.

## Strategy

### Extract execution

- Move the body of `Conductor#execute` (dispatch → `record_step!` → tier check → QA agents →
  blind verification → `close_gate` / `escalate!` → side-effect cleanup) into
  `StepExecution.call(run:, step_id:, piece:, context:)`.
- Preserve ordering, tier semantics, escalation reasons, and `GateCloser`/`DecisionRules` calls
  exactly; this is a refactor, not a rewrite.
- Return a recordable result object carrying status, data, message, findings, verdict, and
  disposition so both callers persist identically.

### RunSequencer

- Encode the canonical full order `A_IDEATE → … → B7 → C1 → C2 → P2_1 → branch → … → P3_8`,
  consolidating `Conductor.order_for`, `PipelineRun.next_step_after`, and `TrackRunner.next_step`.
- Encode conditional branches: P2_1 → P2_2a–e by `placement_branch`; P2_3 only when
  `piece_count > 1`; A2 rewind to A1; A5/B7 confirm re-run semantics.
- Locked-spec shortcut: if a committed style spec exists, A0–A7 are `skipped` ("satisfied");
  same for B0–B7 with a committed scene spec; next runnable starts at C1.
- Expose `next_runnable(run)` and `order_for(run)`.

### CellRunner

- `run_next(run)`: execute the next runnable cell, persist the `RunStep`, mirror `step_results`,
  advance, and stop.
- `run_until_gate(run)`: execute cells until a human gate / tier-3 pause, then stop.
- `run_all(run)`: execute to completion (or the first pause).
- On `awaiting_human` / tier-3: open a `HumanGate`, set the cell `awaiting_human`, stop.
- On failure or blocked/rewind: set the cell `failed`, record escalation, stop.
- Idempotent per cell: re-invoking while running must not double-execute.

### Parity and safety

- Both `Conductor` and `CellRunner` must produce the same `step_results` entries for the same
  run/inputs; add a test that asserts this.
- Do not enqueue jobs yet; keep the services callable directly for tests.

## Validation

- `Conductor` specs remain green after the refactor.
- Parity spec: for a fixed run, conductor output and cell-runner output are equivalent.
- Sequencer specs cover branches, conditional P2_3, rewinds, and locked-spec skips.
- CellRunner stops at the first tier-3/awaiting gate and records a `HumanGate`.
- `rspec spec/services/workflow spec/agents` passes.

## Definition of done

- `StepExecution`, `RunSequencer`, and `CellRunner` exist with specs.
- `Conductor` uses `StepExecution` with no behavioral change (existing specs prove it).
- Single-step execution is callable in isolation and pauses correctly at human gates.
- Full suite passes; `rubocop` is clean.
