# Phase 5 — Realtime Notebook

## Task description

Make the notebook live: add Stimulus controllers for notebook and cell-feedback interaction,
broadcast cell state changes from the execution jobs with Turbo Streams, and configure
SolidCable for development/test so broadcasts reach the browser from background workers.

## Goal

Give the notebook a true real-time feel — cells transition through running/awaiting/done without
manual refresh, the running cell is announced, and feedback previews apply in place.

## Non-goals

- No changes to execution/decision/domain behavior.
- No new orchestration paths; broadcasts are pure presentation.
- No offline/mobile-specific UX.
- No auth or multi-user concerns.

## Deliverables

- `notebook_controller` Stimulus: subscribe to the run stream, autoscroll to the running cell.
- `cell_feedback_controller` Stimulus: compose prose, call `interpret`, render preview, apply.
- Turbo Stream broadcasts from `CellRunner`/`CellRerunner`/`GateApplier` (or the jobs wrapping
  them) at cell start/finish/stale.
- `RunStepJob` (and any run-level job) so execution is async and broadcastable.
- SolidCable configuration for development/test (cable database + `config/cable.yml`).
- System spec exercising live updates.

## Strategy

### Broadcast points

- Broadcast a `replace` for `run_step_<id>` on: start (`running`), completion (`done`/`failed`/
  `awaiting_human`), and staleness changes.
- Broadcast a run-level update for status/header and for the sidebar entry when a run's status
  changes.
- Use `turbo_stream_from @run` and a stable stream key (`run:<run_id>`).

### Jobs

- Wrap cell execution in `RunStepJob` so it runs on SolidQueue and can broadcast.
- Guarantee broadcast-once semantics and idempotent re-runs; never double-render a cell.

### Stimulus

- `notebook_controller`: manage connection/scroll state; highlight the active cell.
- `cell_feedback_controller`: debounced interpret request; swap the preview frame; apply/cancel.
- Retire `pipeline_progress_controller` (replaced by streams).

### Cable configuration

- Development currently uses the `async` adapter with no cable DB, which cannot receive broadcasts
  from separate SolidQueue worker processes. Switch development to `solid_cable`, add a dev `cable`
  database to `config/database.yml` (with `db/cable_migrate`), and keep `test` deterministic.
- Document how to run the worker + web process locally.

### Fallback

- If a stream connection drops, ensure the next user action still renders correctly (server-rendered
  responses remain the source of truth).

## Validation

- System spec: run a cell → observe it transition to `awaiting_human` via stream without reload.
- Manual dev check: web + SolidQueue worker processes, broadcast reaches the browser.
- No duplicate cells or stale fragments after multiple rapid updates.
- Full suite passes; `rubocop` clean.

## Definition of done

- Cell and run state changes appear live in the notebook.
- SolidCable works in development/test with documented run commands.
- System spec for live updates passes.
- Full suite passes; `rubocop` and `erb_lint` are clean.
