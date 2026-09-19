# Phase 1 — Cell Data Model

## Task description

Introduce the persistent storage for notebook cells and per-cell feedback, and wire
`PipelineRunRecord` so its existing `step_results` jsonb stays mirrored from the new cells.
Existing runs are backfilled into cells. No behavior changes to execution, UI, or domain logic.

## Goal

Establish a durable, queryable per-cell state (status, prose summary, structured output, gate
state, feedback history) that later phases can read and write, **without disturbing** the
existing consumers of `step_results` (`Context::Assembler`, `Dossier::Builder`,
`DecisionRules`, and the current `Conductor`).

## Non-goals

- No runner, sequencer, feedback interpreter, summarizer, or UI.
- No removal of any existing code, route, controller, view, or model.
- No change to step classes, prompts, schemas, QA agents, or decision rules.
- No reconstruction of feedback history for pre-existing runs.
- No real-time/broadcast work.

## Deliverables

- Migration `create_run_steps`.
- Migration `create_step_feedbacks`.
- `RunStep` model: associations, status constants/scopes, ordering, validations.
- `StepFeedback` model.
- `PipelineRunRecord` association (`has_many :run_steps`) plus a single mirroring writer that
  keeps `step_results` in sync from cells.
- Backfill rake task (`runs:backfill_cells`) that derives cells from existing `step_results`.
- Factories for `RunStep` and `StepFeedback`.
- Model specs for both, plus a mirror spec.

## Strategy

### Schema design

- `run_steps`: `pipeline_run_record_id`, `step_id`, `position`, `status`, `summary`,
  `output (jsonb)`, `message`, `verdict`, `disposition`, `reviewer_kind`, `escalation (jsonb)`,
  `started_at`, `finished_at`, timestamps.
- Indexes: unique `[pipeline_run_record_id, step_id]`, index `[pipeline_run_record_id, position]`.
- `status` values: `pending`, `running`, `awaiting_human`, `done`, `stale`, `failed`, `skipped`.
- `step_feedbacks`: `run_step_id`, `role` (`human`/`assistant`/`system`), `body`, `parsed (jsonb)`,
  `applied (boolean)`, timestamps; index on `run_step_id`.

### Mirror strategy

- One writer (e.g. `RunStep#mirror_to_run!` or a small `Workflow::StepResultMirror`) is the only
  place that mutates `run.step_results` from cells.
- The mirrored entry must keep the exact shape `Conductor#record_step!` produces today:
  `{ "step_id", "status", "data", "message" (optional), "verdict" (optional), "disposition" (optional) }`.
- Mirroring is idempotent: rebuilding from `run_steps` yields byte-equivalent records for the same
  state.

### Backfill strategy

- Group existing `step_results` by `step_id`, assign `position` using `Workflow::RunSequencer`
  order when available and a stable fallback order otherwise.
- Map recorded statuses to cell statuses (`ok → done`, `awaiting_human → awaiting_human`,
  `failed → failed`).
- Task is idempotent (skip runs that already have cells) and safe to re-run.

### Status transitions

- Document and validate allowed cell transitions; enforce only what is needed now
  (`pending → running → done/awaiting_human/failed`, `done → stale`, `stale → running`).
- Avoid over-constraining so Phase 2 can drive execution.

## Validation

- `bin/rails db:migrate` and `db:rollback` succeed; schema loads cleanly.
- Model specs pass; associations, validations, scopes, and ordering verified.
- Mirror spec proves `step_results` shape is unchanged for a representative run.
- Existing domain specs remain green (especially `spec/agents/conductor_spec.rb`,
  `spec/services/*` for context/dossier, `spec/workflow/*`).
- Backfill task run twice on the same data produces identical output.

## Definition of done

- Migrations are committed and reversible.
- `RunStep`/`StepFeedback` models, factories, and specs are in place.
- `PipelineRunRecord` mirrors `step_results` from cells through a single writer.
- Backfill rake task exists, is documented, and is idempotent.
- Full existing test suite passes unchanged; `rubocop` is clean.
