# Phase 7 — Retirement and Cleanup

## Task description

Remove the retired screens, controllers, routes, jobs, services, and models (including the
KB-evolution stack), prune their specs, and finalize the route/layout cleanup so the notebook is
the single UI surface.

## Goal

End with one coherent UI and no dead code paths, while preserving all domain behavior and keeping
the remaining (domain) specs green.

## Non-goals

- No new features or UI.
- No change to step/agent/decision/commit behavior.
- No deletion of domain specs for steps, agents, knowledge base, or services that remain in use.
- No data loss beyond intentionally dropped, retired tables.

## Deliverables

- Deleted controllers/views: `pipeline`, `reviews`, `human_gates`, `dossier_reviews`,
  `kb_proposals`.
- Deleted jobs: `start_track_job`, `process_piece_job`, `resume_piece_job`, `rerun_from_step_job`,
  `ideate_styles_job`, `propose_job` (and any now-unused run/job wrappers).
- Deleted services: `app/services/kb_evolution/*`, `performance/weekly_export`, and the
  `Workflow::TrackRunner` path once superseded.
- Deleted models/tables: `KbProposal` (+ `kb_proposals` migration); `TrackRun` after backfill
  (if confirmed).
- Pruned specs for all retired items; retained domain specs untouched.
- Final `config/routes.rb` and application layout reflecting only the notebook.

## Strategy

### Deletion order

1. Remove routes, then controllers, then views, then jobs/services, then models/tables — so
   nothing dangling references a deleted constant.
2. Run the suite after each removal to catch residual references.

### Dependency checks

- Grep for constants/methods referenced across app/spec before deleting
  (`TrackRunner`, `KbEvolution::*`, `KbProposal`, retired controller names).
- Confirm `CommitRunJob`, `StepDispatcher`, `HumanGate`, `PieceRecord`, `Context::Assembler`,
  `Dossier::Builder`, and `DecisionRules` remain and are used by the notebook path.

### Spec pruning

- Delete request/system specs for retired screens (e.g. `pipeline_spec`, `reviews_spec`,
  `human_gates_spec`, `dossier_reviews_spec`, `kb_proposals_spec`,
  `system/review_ui_spec`, `system/pipeline_progress_spec`).
- Delete specs tied solely to removed services (`kb_evolution/*`, `weekly_export`).
- Keep step/agent/knowledge-base/service/workflow specs.
- Update shared/coverage specs that enumerate routes or files.

### Layout and navigation

- Simplify `layouts/application.html.erb` to the notebook shell; remove dead nav/flash handling no
  longer used.
- Ensure `root` resolves correctly and no retired paths remain in `routes.rb`.

### Documentation

- Update the main plan/README references; note removed subsystems.

## Validation

- `bin/rails routes` shows only intended routes.
- Full `rspec` suite passes with no references to deleted constants.
- `tools/scripts/validate/*` (syntax, format, security, db, etc.) pass.
- `rubocop` and `erb_lint` clean.
- Manual smoke: create a run, run cells, approve the dossier.

## Definition of done

- All retired screens, jobs, services, models, tables, and specs are removed.
- The notebook is the only UI surface; routing and layout are clean.
- Domain behavior is unchanged and the full suite passes.
- Validators, `rubocop`, and `erb_lint` are clean.
