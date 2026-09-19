# Notebook UI Overhaul — Implementation Plan

## Implementation status

Phases 1–7 are implemented: cell data model (`RunStep`/`StepFeedback`), shared execution engine
(`Workflow::StepExecution` + `RunSequencer` + `CellRunner`), feedback/summaries (`Llm::*` +
`CellRerunner`/`GateApplier`), notebook controllers/views, realtime Turbo Streams, dossier approval
and staleness, and retirement of the legacy screens/jobs/services. The notebook is served at `/`
and `/runs`.

## Purpose and scope

This document plans a **presentation-and-interaction overhaul** of the human review surface:
a single-page, Jupyter-like notebook where one run is a vertical sequence of step cells, each
cell reading as prose and accepting plain-English feedback. It also plans the small amount of
orchestration glue needed to drive steps one cell at a time and keep a run's records in sync.

The scope is deliberately narrow so the work does not drift into the pipeline's domain logic.
Use the lists below to decide whether a proposed change belongs in this effort.

### What this is

- A **UI/UX replacement**: the flat dashboard, `reviews`, `human_gates`, `dossier_reviews`, and
  `kb_proposals` screens are retired in favor of one notebook shell (sidebar of runs + cell list).
- A **unified run model**: every run is one `PipelineRunRecord` covering `A_IDEATE → P3_8` and
  culminating in one dossier. Cells live in a new `run_steps` table (with per-cell feedback
  history in `step_feedbacks`).
- A **natural-language feedback layer**: prose is translated by an LLM into a structured step
  decision (approve / edit / reject / re-run), constrained by the existing `DecisionRules`, and
  shown for confirmation before it is applied.
- **Cell-level execution and re-run**: a new per-step runner plus a sequencer; re-running a cell
  marks downstream cells stale and the user re-runs them manually.
- **Readable output**: each cell carries an LLM-written prose summary persisted at step time,
  replacing raw JSON as the primary rendering (JSON becomes a collapsed detail).
- **Real-time updates**: Turbo Streams over SolidCable, replacing manual refresh/polling.
- **Orchestration refactoring only**: extracting the existing per-step execution path
  (`Conductor#execute`) into a shared `StepExecution` service so the conductor and the notebook
  runner share identical QA/gating behavior.

### What this is not

- **Not a change to pipeline semantics.** Step classes, prompts, LLM schemas, knowledge-base
  rules, QA agents, verdicts, dispositions, tiers, and `DecisionRules` remain authoritative and
  untouched in behavior. If a cell output is wrong, the fix belongs in the step, not here.
- **Not a change to step order or the step registry.** `RunSequencer` encodes the *existing*
  order and branches; it does not introduce, remove, or reorder steps.
- **Not new agent/LLM product behavior.** `CellSummarizer` and `FeedbackInterpreter` are
  additive presentation aids; they must not override, reinterpret, or bypass `DecisionRules`.
- **Not a commit/publish redesign.** `CommitRunJob` remains the only committed replay path
  (write spec → git commit → publish to Etsy). Approving the dossier simply invokes it.
- **Not a multi-user/productization feature.** No authentication, accounts, roles, permissions,
  collaboration, or audit UI beyond what already exists. It stays a single-operator tool.
- **Not an integration rewrite.** LLM provider wiring, image generation, Etsy API, search, and
  the compositor are out of scope.
- **Not a general code-execution notebook.** Cells are pipeline steps, not arbitrary snippets.
  There is no kernel, REPL, or user-supplied code execution.
- **Not a data-recovery project.** Existing runs are backfilled from `step_results` on a
  best-effort basis; feedback history for old runs is not reconstructed.
- **Not a backwards-compatibility promise.** Old routes, controllers, views, and their specs are
  intentionally deleted rather than shimmed.
- **Not a visual/branding redesign** beyond what the notebook layout requires.

### Assumptions

- Single operator; no auth layer is added.
- Domain specs and step/agent/service specs stay green and are the contract for "no semantic
  change"; only UI specs for retired screens are rewritten or deleted.
- `RubyLLM` and `Pipeline::TEXT_MODEL` are available for the summarizer and interpreter.
- A markdown renderer may be added for the dossier/summary rendering.

## 1. Mental model (locked)

- **Run** = one `PipelineRunRecord` whose cells span the full journey `A_IDEATE → P3_8`, producing one dossier. Every run is `scope: "full"`.
- **Cell** = one pipeline step, stored in a new `run_steps` table, rendered like a notebook cell.
- Sidebar lists runs; main pane is the notebook for the selected run.
- A cell shows: title/step id, status, an **LLM-written prose summary**, collapsible structured detail, and a **feedback composer**.
- Feedback is prose → an LLM interprets intent + edits → user confirms the parsed result → it is applied.
- Re-running a cell **marks downstream cells stale**; they are re-run manually.
- Human gates pause the run mid-notebook; approving the final dossier cell triggers `CommitRunJob`.
- Live updates via **Turbo Streams over SolidCable**.
- Old screens and the KB-evolution stack are removed.

## 2. Data model

### New: `run_steps` (the cells)

`pipeline_run_record_id (FK)`, `step_id`, `position`, `status` (`pending/running/awaiting_human/done/stale/failed/skipped`), `summary (text)`, `output (jsonb)`, `message (text)`, `verdict`, `disposition`, `reviewer_kind`, `escalation (jsonb)`, `started_at`, `finished_at`, timestamps. Unique `[pipeline_run_record_id, step_id]`; index `[pipeline_run_record_id, position]`.

### New: `step_feedbacks` (per-cell history)

`run_step_id (FK)`, `role` (`human/assistant/system`), `body (text)`, `parsed (jsonb)`, `applied (bool)`, timestamps. Gives the notebook a real conversation/history per cell.

### Change: `PipelineRunRecord`

- `has_many :run_steps, -> { order(:position) }`
- Keep `step_results` jsonb **mirrored** from `run_steps` on every update, so `Context::Assembler`, `Dossier::Builder`, `DecisionRules` and existing domain specs keep working unchanged.
- `scope` stays but is always `full`.

### Retire

`KbProposal` model + `kb_proposals` table; optionally `TrackRun` after migration.

Migrations: `create_run_steps`, `create_step_feedbacks`, backfill existing `PipelineRunRecord#step_results` into cells (rake task), drop `kb_proposals`.

## 3. Backend services

1. **`Workflow::StepExecution.call(run:, step_id:, piece:, context:)`** — factor `Conductor#execute` out: runs `StepDispatcher`, QA agents, `BlindVerifier`, `DecisionRules`, `GateCloser`, escalation capture. Returns a recordable result. `Conductor` and the cell runner both call this, so QA/gating semantics stay identical.

2. **`Workflow::RunSequencer`** — single source of truth for ordering and branches: generalizes `Conductor.order_for`, `PipelineRun.next_step_after`, and `TrackRunner.next_step` (P2_1 branch 2a–2e, P2_3 conditional, A2 rewind, A5/B7 confirm). Computes "next runnable cell" from current cell states.

3. **`Workflow::CellRunner`** — `run_next(run)` / `run_until_gate(run)` / `run_all(run)`:
   - assemble context → `StepExecution` → upsert `run_step` → mirror `step_results` → broadcast.
   - On `awaiting_human` / tier-3 gate: open `HumanGate`, set cell `awaiting_human`, stop.
   - Else advance (or stop, if only "run next").
   - **Locked-spec shortcut**: if a committed style spec exists, create A0–A7 as `skipped` ("satisfied by locked spec"); same for B0–B7 if the scene spec exists; start at C1.
   - Runs inside `RunStepJob` so it is async and can broadcast.

4. **`Workflow::CellRerunner`** — given cell + applied decision: clear side effects, reset the cell, mark all downstream cells `stale`, truncate the mirrored `step_results` from that step onward, and extend `Context::Assembler`'s taint rule to treat `stale` like `failed`/`rewind`. Then run the cell.

5. **`Llm::FeedbackInterpreter`** (RubyLLM + new `Schemas::FeedbackInterpretationSchema`) — input: cell (step, summary, gate question, output) + prose. Output: `{ intent, notes, edits, reason, override_reason, acceptance_note }`, constrained by `DecisionRules.legal_dispositions`. Two calls: `interpret` (returns preview) and `apply`.

6. **`Llm::CellSummarizer`** (RubyLLM) — generates the 2–5 sentence paragraph at step completion, persisted to `run_step.summary`; falls back to the `Dossier::Builder` narrative on failure.

7. **`Workflow::GateApplier`** — replaces `HumanGatesController` logic: validate via `DecisionRules.validate_disposition!`, close the gate, update the cell, then advance or mark stale.

## 4. Routes & controllers

```
root "runs#show"                       # last run, or index shell
resources :runs, only: [:index, :show, :create] do
  post :run_all,    on: :member
  post :approve,    on: :member         # CommitRunJob
  post :abandon,    on: :member
  resources :steps, only: [], controller: "run_steps" do
    member do
      post :run
      post :interpret     # returns parsed preview (Turbo Frame)
      post :decision      # apply confirmed decision / rerun
    end
  end
end
```

New: `RunsController`, `RunStepsController`. Zero implementation in the controller beyond params → service → Turbo response.

## 5. Views / front-end

- Persistent **sidebar** (part of the notebook layout): run list with status dot, style/scene, relative time, "New run" button.
- **New run** modal: `style_slug`, `style_name`, `scene_spec_id` (scene image derived).
- **`_cell.html.erb`**: `[n]` index, step title from `step_registry.yml`, status badge, prose summary, `<details>` structured output (per-step presenters where easy, pretty JSON otherwise), searches/images, gate question, and the feedback composer.
- **Dossier cell** (final): rendered markdown from `dossier_markdown` + Approve & commit / Abandon. Requires a markdown renderer gem (e.g. `commonmarker`) — currently absent from the Gemfile.
- **Stimulus**: `notebook_controller` (subscribe to stream, autoscroll to running cell), `cell_feedback_controller` (interpret → preview → apply/cancel), status control. Retire `pipeline_progress_controller`.
- **Turbo Streams**: `turbo_stream_from @run`; `RunChannel`/broadcast on cell start/finish/stale. Switch **development** `cable.yml` to `solid_cable` and add a dev `cable` database (today it's `async` with no cable DB, which will not receive broadcasts from SolidQueue workers).

## 6. Removals

- Controllers/views: `pipeline`, `reviews`, `human_gates`, `dossier_reviews`, `kb_proposals`.
- Jobs: `start_track_job`, `process_piece_job`, `resume_piece_job`, `rerun_from_step_job`, `ideate_styles_job`, `propose_job`.
- Services: `app/services/kb_evolution/*`, `performance/weekly_export`, and the `Workflow::TrackRunner` path (superseded by `CellRunner` + `RunSequencer`).
- Models: `KbProposal` (+ table). `HumanGate` and `PieceRecord` stay as internal audit/artifact records; `TrackRun` can be dropped after backfill.
- Specs: delete retired UI specs; **keep** all step/agent/service/domain specs. Add new specs for the services and UI.

## 7. Testing

- Service specs: `RunSequencer`, `StepExecution`, `CellRunner`, `CellRerunner`, `GateApplier`, `FeedbackInterpreter`/`CellSummarizer` (stub RubyLLM).
- Request specs: runs create/show, step run/interpret/decision, dossier approve.
- One system spec: create run → cells stream in → gate feedback → re-run marks downstream stale → approve dossier.
- Run `tools/scripts/validate/*` + `rubocop` + `erb_lint` before finishing.

## 8. Phases

Each phase has its own file with Task description, Goal, Non-goals, Deliverables, Strategy,
Validation, and Definition of done.

1. [Phase 1 — Cell Data Model](notebook-ui-phases/phase-1-data-model.md): migrations + models
   (`RunStep`, `StepFeedback`) + save/mirror hooks.
2. [Phase 2 — Execution Engine](notebook-ui-phases/phase-2-execution-engine.md): factor
   `StepExecution`; build `RunSequencer` + `CellRunner` (service specs only, no UI).
3. [Phase 3 — Feedback Interpretation, Summaries, Re-run](notebook-ui-phases/phase-3-feedback-and-summaries.md):
   `FeedbackInterpreter`, `CellSummarizer`, schemas; `CellRerunner`, `GateApplier`.
4. [Phase 4 — Controllers and Views](notebook-ui-phases/phase-4-controllers-and-views.md):
   `RunsController`/`RunStepsController` + ERB notebook + sidebar (form posts, Turbo Frames).
5. [Phase 5 — Realtime Notebook](notebook-ui-phases/phase-5-realtime-ui.md): Stimulus feedback
   composer + Turbo Streams + cable config.
6. [Phase 6 — Dossier Approval and Staleness Polish](notebook-ui-phases/phase-6-dossier-and-staleness.md):
   dossier approval/commit + staleness polish.
7. [Phase 7 — Retirement and Cleanup](notebook-ui-phases/phase-7-cleanup.md): delete retired
   code/specs; final route/layout cleanup.

## 9. Open items (defaults)

- **Markdown**: add `commonmarker` to render the dossier and cell summaries.
- **Skipping**: a committed style spec skips A0–A7; a committed scene spec skips B0–B7; otherwise they run. Cells show as "satisfied".
- **Performance stats**: remove the Refresh/Export/Propose dashboard actions along with the evolution stack; `Performance::EtsyStatsFetcher` and `performance_snapshots` stay as data-only (no UI) unless they should be removed too.
- **Backfill**: existing runs get cells derived from `step_results`; no attempt to reconstruct feedback history.
