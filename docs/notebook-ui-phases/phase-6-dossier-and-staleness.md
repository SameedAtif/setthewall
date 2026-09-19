# Phase 6 — Dossier Approval and Staleness Polish

## Task description

Complete the review loop: render the dossier as the final notebook cell (readable markdown) with
Approve & commit / Abandon actions wired to `CommitRunJob`, and polish staleness and re-run
affordances across the notebook.

## Goal

Let an operator read the assembled dossier in the notebook, approve it to trigger the committed
replay, or abandon it — and clearly see which cells are stale and need re-running before doing so.

## Non-goals

- No change to `CommitRunJob` semantics (write spec → git commit → publish).
- No redesign of Etsy publish, pricing, or shipping logic.
- No new pipeline steps or decision rules.
- No changes to the execution engine.

## Deliverables

- Dossier cell partial rendering `dossier_markdown` as formatted markdown.
- Markdown rendering (add a renderer gem if needed) with safe output.
- `approve` / `abandon` controller actions → `CommitRunJob` / status update + Turbo response.
- Staleness UX: visual treatment, "stale — re-run" actions, and guidance when stale cells block
  approval.
- Request + system specs for approve, abandon, and stale flows.

## Strategy

### Markdown rendering

- Add a markdown renderer (e.g. `commonmarker`) and a sanitized helper for `dossier_markdown` and
  any rich cell summaries.
- Keep raw/diagnostic detail available in a collapsed block.

### Approval flow

- The dossier cell shows run metadata, escalations/open questions, and the "if you approve" action.
- Approve invokes `CommitRunJob` (unchanged) and reflects `committed` status via Turbo Stream.
- Abandon sets `abandoned` and stops further runs.
- Block approval (or warn prominently) while any required cell is `stale`, since the dossier may
  not reflect the current outputs.

### Staleness polish

- Clear visual distinction for `stale` cells and a one-click re-run.
- Show a "notebook is stale" banner on the run when downstream cells are stale.
- After re-running stale cells, the dossier should be regenerated (rebuild `dossier_markdown`)
  before approval.

### Dossier freshness

- Ensure the dossier is (re)built from the current cell state on demand or after the final cell
  completes, so approval always reflects current outputs.

## Validation

- Request specs: approve triggers `CommitRunJob`; abandon updates status; approve blocked/warned
  when stale.
- System spec: stale cell → re-run → dossier refreshed → approve.
- Manual: dossier renders readably; commit path works with Etsy stubbed.
- Full suite passes; `rubocop` and `erb_lint` clean.

## Definition of done

- The dossier is readable in the notebook and approval triggers the committed replay.
- Stale cells are obvious and re-runnable, and the dossier reflects the latest state before
  approval.
- Request/system specs pass.
- Full suite passes; validators clean.
