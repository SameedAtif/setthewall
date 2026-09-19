# Phase 4 — Controllers and Views

## Task description

Build the notebook UI as a single page: a persistent sidebar of runs and a main pane of step
cells, driven by `RunsController` and `RunStepsController`. This phase uses standard form posts and
Turbo Frames (no cable/realtime yet) and renders the dossier cell. The old screens remain in place
until Phase 7.

## Goal

Deliver an end-to-end usable notebook — create a run, watch cells populate on reload, run the next
cell, re-run a cell, and submit feedback with a confirmation preview — using server-rendered views
only.

## Non-goals

- No Stimulus controllers, Turbo Streams, or ActionCable (Phase 5).
- No deletion of existing screens/routes (Phase 7).
- No change to execution/feedback services beyond wiring.
- No new domain behavior.
- No markdown rendering beyond what already exists (final formatting lands in Phase 6).

## Deliverables

- Routes for `runs` and nested `run_steps` (see main plan §4).
- `RunsController` (`index`, `show`, `create`, `run_all`, `approve`, `abandon`).
- `RunStepsController` (`run`, `interpret`, `decision`).
- Notebook layout with persistent sidebar.
- Partials: sidebar/run list, notebook header, `_cell`, dossier cell, new-run form.
- Request specs and a basic system spec (non-realtime).

## Strategy

### Routing and controllers

- `root` points at `runs#show` (latest run) with an index shell when no runs exist.
- Controllers stay thin: params → service (`CellRunner`, `CellRerunner`, `GateApplier`) → Turbo
  response. No orchestration logic in controllers.

### Layout and sidebar

- Persistent left sidebar: run list (status dot, style/scene, relative time), "New run" button.
- Main pane: run header (id, style/scene, status, run-all) + ordered cells.

### Cells

- `_cell` renders index `[n]`, step title from `config/step_registry.yml`, status badge, prose
  `summary`, a collapsed `<details>` structured-output block, searches/images where relevant, and
  the gate question when `awaiting_human`.
- Feedback composer posts prose to `interpret`, which returns a Turbo Frame containing the parsed
  decision preview (intent + fields) with Apply/Cancel; Apply posts to `decision`.

### Forms and states

- Distinct rendering per cell status: `pending`, `running`, `awaiting_human`, `done`, `stale`,
  `failed`, `skipped`.
- Stale cells show a clear "stale — re-run" affordance.
- New-run form: `style_slug`, `style_name`, `scene_spec_id`.

### Progressive interaction

- Use Turbo Frames for the interpret-preview and for replacing a single cell after run/decision,
  so the page doesn't fully reload for every interaction.

## Validation

- Request specs: run creation, notebook rendering, step run, interpret preview, decision apply,
  run-all, dossier approve/abandon.
- System spec (no cable): create run → cells render → submit feedback → preview → apply.
- Manual happy path against a dev run.
- Existing suite still green; retired screens still function until Phase 7.

## Definition of done

- Sidebar + notebook render for real runs with all cell states.
- A user can create a run, run cells, re-run with feedback, and view the dossier via full-page /
  Turbo Frame interactions.
- Request specs and the non-realtime system spec pass.
- Full suite passes; `rubocop` and `erb_lint` are clean.
