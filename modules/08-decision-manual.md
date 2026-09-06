# Module 08 — Decision Manual

> **Self-contained.** No new domain rules, no new pipeline states, no schema changes. This module
> answers one question that modules 00–07 leave open: when a step pauses at a human gate, what is
> the reviewer allowed to answer, and where does a rejection actually go?

---

## Contract

**Depends on:** module 00 (`step_registry.yml`, `Steps::Base`, `StepResult`), module 06
(`PieceRecord.status`, `HumanGate`, `StepDispatcher`, `StatusMachine`), modules 01–05 (every step
whose exit conditions this manual classifies), module 01c (`TrackASession`).

**Provides:**
- `knowledge_base/rules/decision_rules.yml` — the machine-readable rule file: verdicts,
  dispositions, the legality matrix, ten standing rules, budgets, and a per-step entry for all
  40 pause points.
- This document — the human-readable manual and the reasoning behind each rule.

**Consumed by:** module 09's conductor and QA agents (the primary consumer — every automated gate
closure is bounded by the legality matrix here); module 06's dispatcher and review UI; module 07's
`WeeklyExport`, which reads gate decisions and can now read the verdict that produced them.

**Reviewer-agnostic by design.** Nothing in this module assumes the reviewer is a person. A
disposition is legal or illegal based on the verdict alone. `HumanGate.reviewer_kind` (added in
module 09) records who closed it. The rules do not soften for an agent; several of them exist
specifically because an agent will otherwise take the illegal option by default.

**Must not:** add states to `PieceRecord.status`, add columns to `piece_records`, restate any
domain rule that modules 01–05 already own, or introduce a numeric performance threshold that no
source document supports.

---

## 1. The gap this closes

Module 06 §4 defines a real state machine, but every transition points forward:

```
pending        → running | failed
running        → pending | awaiting_human | complete | failed
awaiting_human → running | failed
complete       → (terminal)
failed         → running | pending
```

There is no backward transition, and module 06 §8.3 says so in a comment on
`HumanGatesController#update`: on a rejected gate, the piece is left for the human to decide the
next move, "usually: rerun the previous step with different context, or abandon." That one
sentence is currently the pipeline's entire rule for the case you asked about — a step returns a
mixed result and the correct response is to go back and change something upstream.

Three specific things are missing.

**No classification of what a pause means.** Every gate arrives at the reviewer looking identical:
a proposal, a message, and three buttons. But A2 returning `mixed` and A4 returning
`consistency: mixed` are opposite situations. A4's mixed reading has a documented tiebreaker and
resolves; A2's has a documented rule that says explicitly *do not force a call, narrow the
reference set and return to A1* (module 01 §2.2, `mood.yml` `scoring.mixed_result`). Approving A2
is a rule violation. The UI currently makes it one click.

**No rewind targets.** A2 already carries `recommended_action: "return_to_a1"` in its result data
(module 01 §6.3). Only three steps in 38 do. Every other rejection has no defined destination.

**No invalidation graph.** Module 01c §3 has the only dependency map in the project
(`TrackASequence::SOURCES`), and it covers A_IDEATE→A5. If you rewind to A2 and change the mood,
A4 is stale because it consumed that mood as its tiebreaker — nothing anywhere records that.

---

## 2. Six verdicts

The classification is of the *step's result*, not the reviewer's answer. It is computed by the
step, or derived from the step's existing exit conditions where the step predates this module.

| Verdict | What it means | What the reviewer is being asked |
|---|---|---|
| `clean` | Output produced, every mechanical check passed | Do you agree with a well-supported proposal? |
| `flagged` | Output produced, an **advisory** check failed; the step offered to proceed anyway | Do you accept this named risk? |
| `unresolved_perception` | The agent could not read the answer, but one exists and you can supply it | Supply the value |
| `unresolved_input` | **No** single answer exists; the input set is heterogeneous or too broad | Which upstream step do you go back to? |
| `contradicted` | Output conflicts with a locked value, a documented default, or a cross-check | Which source wins, and why? |
| `blocked` | Hard failure; a precondition is absent or a non-negotiable rule was violated | Nothing — fix it or rewind |

The distinction that does the most work is `unresolved_perception` versus `unresolved_input`, and
it comes straight out of the source documents.

B3 (Room Type) returning `ambiguous` is a perception problem. `borderline_defaults.yml` marks it
`escalate: true` with the reason "eye-level formulas are not interchangeable" — the step's own
message asks the human to classify the room as `seated_room`, `hallway`, or `no_furniture_wall`.
The answer exists; a person looking at the scene photo knows it. Supplying it is correct.

A2 returning `mixed` is not that. The rule file says a genuinely mixed scorecard means the
reference set itself is not focused enough yet. There is no right mood to supply, because the set
contains two. Supplying one is manufacturing evidence.

Same word, opposite response. Collapsing them into one "ambiguous" bucket is how the A2 rule gets
skipped under time pressure, which is the exact failure module 01 §6.3 says it enforced in code to
prevent.

---

## 3. Five dispositions, and which are legal

| Disposition | Effect | `HumanGate.status` |
|---|---|---|
| `approve` | Resume with the agent's proposal as-is | `approved` |
| `edit` | Resume with the reviewer's values | `edited` |
| `retry` | Re-run the **same** step with new context | `rejected` |
| `rewind` | Re-run a **named upstream** step; clear everything it invalidates | `rejected` |
| `abandon` | Stop this piece or style | `rejected` |

`retry` and `rewind` both map to `rejected`, which is what module 06 §8.3 already does — the
controller does not enqueue a resume on rejection. The manual adds the required `notes` content
that says which one it was.

### The legality matrix

This is the core of the manual. The verdict determines which answers are available.

| | approve | edit | retry | rewind | abandon |
|---|---|---|---|---|---|
| `clean` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `flagged` | ✓ (+ note) | ✓ | ✓ | ✓ | ✓ |
| `unresolved_perception` | — | ✓ | ✓ | ✓ | ✓ |
| `unresolved_input` | — | — | ✓ | ✓ | ✓ |
| `contradicted` | — | ✓ (+ reason) | ✓ | ✓ | ✓ |
| `blocked` | — | — | ✓ | ✓ | ✓ |

Reading the four dashes:

- `unresolved_perception` has no `approve` because there is no proposal to approve. The step
  returned no value.
- `unresolved_input` has neither. This is the A2 rule generalised. `approve` accepts an answer the
  evidence does not support; `edit` invents one. Both are the forcing move the source prohibits.
  The only legal answers move the problem to where it actually is.
- `contradicted` has no bare `approve` because approving a contradiction picks a winner without
  recording why. B6 already demands the reason explicitly — its `catalog_strategy_override` is
  mandatory when the `minimalist_modern` → `line_only` default (p. 97) overrides the observed
  candidate. Generalised, an override always carries a reason.
- `blocked` has neither, because a `fail_step` is not a proposal. The load-bearing case is P2_6's
  coverage cap, and it is worth being blunt about why.

### Why a reviewer cannot approve past P2_6

*At Home with Pictures* p. 51 treats wall coverage as binary: stay under two-thirds of the wall,
or cover it fully and consistently as a deliberate maximalist choice. A partial overreach past
two-thirds reads as a mistake, and there is no in-between. Module 04 §2.11 encodes exactly that as
a forbidden band (`0.6667 < coverage_fraction < 0.95`) with `on_forbidden: fail_step`, and notes
it is enforced in code rather than left as prose.

That is a numeric rule with a page citation behind it. It is not a risk to accept, so it is
`blocked` rather than `flagged`, and no button exists. The same holds for the rest of P2_6's
checks, all from p. 63: the 8–10″ gap between the bottom of a group and the furniture beneath it;
the group no wider than the furniture and at least half its length; eye level at 5–6″ above the
backs of couches or chairs in seated rooms and at or just above eye level in a hallway; and the
3–4″ drop applied on top, because hanging too high is described there as one of the most common
picture-placing mistakes. Phase 2 §6 Limitation 1 is explicit that none of these can be trusted to
a generative model. They should not be trusted to a tired reviewer at 11pm either.

---

## 4. Rewind

### 4.1 Targets

Every step entry in `decision_rules.yml` carries `rewind_to`. Most are obvious from the data flow.
Three are worth naming here because they are the ones you will actually hit:

- **A2 → A1.** Documented already as `recommended_action: "return_to_a1"`.
- **P2_3 → C2_finalists.** Module 04 §6.4's own message offers "proceed with this set or return to
  Track C for a tighter cull."
- **C2 stage 2 → C2 stage 1 → C1.** Two separate gates, so two separate rewind depths.

### 4.2 Invalidation

A rewind clears every downstream field the rewound step feeds. The graph is derived from three
sources that already exist: module 01c §3's `SOURCES` table for Track A, the `X1`–`X5` handoffs in
the manifest, and each step's `context.fetch` calls.

The non-obvious edges:

- **A3 does not invalidate A4.** A4 consumes mood (from A2), not content type. It invalidates A5 only.
- **A2 does invalidate A4** even when A4 was clean, because A4 used the old mood as its tiebreaker.
- **B1 and B2 invalidate P2_4 and P2_5** respectively, across the whole Phase 1 → Phase 2 boundary.
- **P2_6 does not invalidate P3_1b's Lifestyle photo by regenerating it.** X4 makes the composite
  authoritative; P3_1b explicitly does not regenerate it. A rewind to P2_6 replaces
  `composite_url`, and P3_1b picks up the new one.

### 4.3 Crossing a lock

A5 and B7 write files into `knowledge_base/`. Module 00 §1.1 is unambiguous that git is the
version history, the audit trail, the validation gate, and the rollback, and that no second
rollback system should be built. So a rewind past a lock requires a `git revert` of the written
spec before the upstream step re-runs. `Workflow::PreflightCheck` already refuses to run against
an uncommitted knowledge base; this extends the same guard to the rewind path.

### 4.4 Budgets

Per style: two rewinds to A1, then A0's go/no-go re-opens or the style is abandoned. Per scene:
two rewinds inside Track B, then the template itself is the problem. Per piece: one rewind to C2,
one to C1, two retries of any single step, then the piece is abandoned for today's run.

Universally: **a retry with unchanged context is refused.** Re-running a step against identical
input is not a decision.

These numbers are project conventions. No source prescribes them. They operationalise the
maximizer principle from *The Paradox of Choice* — more iterations do not produce a better
decision, they produce a later one carrying more regret — the same way module 03 §2.1 handles its
batch cap, and with the same honesty note in the rule file's `meta`.

---

## 5. Standing rules

Ten rules that override any step-level entry. Full text in `decision_rules.yml`
`rules.standing_rules`. The three that matter most:

**SR2 — never force a call on `unresolved_input`.** The generalisation of A2. Fix the input; do
not supply the output. Exactly one documented exception exists, at P2_3, where module 04 §6.4
itself names proceeding as a legitimate option.

**SR4 — work already spent is never an input to a rewind decision.** This is the rule a reviewer,
human or agent, will most want to break.

*Influence* Ch. 7 finds that commitment decisions, even erroneous ones, are self-perpetuating:
people generate new justifications for them after the fact, so commitments persist long after the
conditions that produced them have changed. *The Paradox of Choice* makes the complementary point
about sunk costs — that sensitivity to them is a mistake in any future-oriented decision model,
and that the effect is strongest when the person bears responsibility for the original decision.
The reviewer here is always that person.

The practical form of SR4 depends on who is reviewing. For a human at module 06's UI, the gate
screen must not display elapsed time, step count, or accumulated generation cost. Module 06 §8.4's
index view shows `time_ago_in_words(gate.opened_at)`, which is fine on a task list and must not
appear on the decision screen.

For an agent reviewer, the same rule applies to the prompt: a QA agent must never be told what the
run has cost, how long it has taken, or how many steps have already succeeded. And it applies to
module 09's dossier, which must not open with a cost or duration summary. A dossier that leads with
"14 steps, 42 minutes, $3.80" invites approval of a weak run because it was expensive, which is the
same failure at a different layer.

**SR7 — batch strategy changes to P2_7.** Within-run defects are decided at their gate,
immediately. Decisions about *which* style, *which* scene, or whether next week repeats, extends,
or rotates go to the weekly review and nowhere else. *The Art of Small Business Social Media*
Ch. 31 makes the case: a planned calendar exists so the approach is consistent rather than
haphazard, and quick fixes feel manageable in the short term while failing to produce meaningful
results. Mid-run strategy changes are the "random acts of marketing" that chapter names.

---

**SR11 — an agent disposition without a resolvable citation is void.** Every gate closed by an
agent must name at least one `rule_path` that resolves to a real key in a real file under
`knowledge_base/`. A citation that does not resolve fails the gate closed and escalates. This is
the mechanism that keeps a fluent agent from producing a confident, ungrounded approval, and it is
checked independently by module 09's evidence QA rather than self-reported.

**SR12 — tier governs who may close a gate.** Every step carries a `tier` in `decision_rules.yml`.
An agent may close Tier 1 alone and Tier 2 only under module 09's blind-verification protocol. No
agent may close a Tier 3 gate under any verdict, including `clean`.

### 5.1 Tier assignment

| Tier | Who closes it | Steps |
|---|---|---|
| 1 | One agent, citation required | A_IDEATE, B1, B2, B4, B5, C1, P2_2a–e, P2_4, P2_4b, P3_1, P3_3, P3_4, P3_8 |
| 2 | Two agents, blind verification | A1, A2, A3, A4, B3, B6, C2 stage 1, P2_1, P2_3, P2_5, P2_6, P3_1b, P3_2, P3_5, P3_6 |
| 3 | Human only, never delegated | A0, A5, B0, B7, C2 stage 2, P2_0, P2_7, P3_7 |

Tier 3 has eight entries and one reason each. A0 and C2 stage 2 are stop decisions, and Phase 2 §6
says agents are bad at knowing when they have hit good enough. A5, B0, B7 and P2_0 are locks and
staleness checkpoints, where the failure mode is silent propagation into a week of production.
P2_7 is strategy the ownership tag reserves outright, and P3_7 is pricing that no input contains.

A2, A3 and A4 sit in Tier 2 rather than Tier 3 even though Track A determines the brand's point of
view, because module 09 runs them speculatively and their output is not committed until the human
approves A5. The lock is the gate; the classifications feeding it are proposals.

## 6. What a successful run is

Since conversion data is deferred, success is defined entirely on decision quality, which is
measurable today from `HumanGate` rows.

A run succeeds when:

- **S1** Every gate closed with a disposition legal for its verdict. Query: no `HumanGate` row
  where `status = approved` and verdict is `unresolved_input`, `unresolved_perception`, or `blocked`.
- **S2** No `blocked` verdict remains unresolved at publish.
- **S3** Every approved `flagged` verdict carries a non-empty acceptance note.
- **S4** Every edited `contradicted` verdict carries a non-empty override reason.
- **S5** All P2_6 numeric checks passed, and not by shrinking the art purely to dodge the cap.
- **S6** `kb_version` does not start with `dirty:` — the run is reproducible.
- **S7** No budget was exhausted.
- **S8** No scene axis reached B7 marked `resolved_by_default` without acknowledgement (SR10).
- **S10** Every disposition closed by an agent carries at least one citation that resolves to a
  real path in a real rule file (SR11).
- **S11** No Tier 3 gate was closed by an agent (SR12).

S1 is the one that matters. It is a single query, it runs on data module 06 already stores, and
it detects the specific failure this whole module exists to prevent.

**What is deliberately not here:** any conversion, view, favourite, or revenue threshold. Module
05 §2.1 records that Etsy treats listing engagement rate as a trust signal rather than only a
sales metric, and module 07 §4.1 computes `conversion_rate` per snapshot. Neither states a target.
Inventing one would be precisely the unsourced inference `etsy_antipatterns.yml` exists to block —
that file already stops the evolution loop from "discovering" that renewal-chasing works. Add
thresholds after a baseline window of real data, as `S9`.

---

## 7. Which claim came from which document

| Rule | Source set | Specific citation |
|---|---|---|
| P2_6 coverage cap is `blocked`, not `flagged` | Arrangement | *At Home with Pictures* p. 51 (binary: under two-thirds or fully maximalist) |
| P2_6 numeric checks (gap, width, eye level, drop) | Arrangement | p. 63 (8–10″ gap; group no wider than furniture, at least half its length; 5–6″ above seat backs; 3–4″ drop) |
| B3 has no safe default | Arrangement | p. 63 — the three eye-level formulas are not interchangeable |
| P2_5 weight balance is `flagged` not `blocked` | Arrangement | p. 63 — dark furniture *requires* lighter art; light furniture only *allows* heavier art |
| P2_2a focal treatment | Arrangement | p. 27–28 — isolation plus an oversized frame reads as focal; the same piece in a cluster blends in |
| P2_2b count and symmetry | Arrangement | p. 63 (odd groups dynamic, even calmer); p. 68–69 (subject energy overrides mood on symmetry) |
| P2_3 theme unification; tight spacing for theme sets | Arrangement | p. 101 (repeat don't clone; proximity reinforces) vs p. 63 (several inches for general groupings) |
| B6's `line_only` override | Arrangement | p. 97, via module 04 §2.2a |
| SR2, and the A2 → A1 rule | Business | *The Paradox of Choice*, satisficer bar — commit to a bar rather than keeping the option open |
| Budgets and the batch cap logic | Business | *The Paradox of Choice*, Ch. 5–6, maximizer trap (numbers are project convention, not prescribed) |
| SR4 anti-sunk-cost, and the UI constraint | Business | *Influence*, Ch. 7 — commitments grow their own justifications; *The Paradox of Choice* — sunk-cost sensitivity is a mistake, strongest when you own the original decision |
| A0's go/no-go bar | Business | *This Is Marketing*, Ch. 4 / Ch. 8 — smallest viable market |
| C2's finalist is a commitment | Business | *This Is Marketing*, Ch. 12 — trust and tension create forward motion |
| P3_6 rejects "for everyone" | Business | *This Is Marketing* — a listing claiming a universal audience has none |
| SR7 batch strategy to the weekly gate | Business | *The Art of Small Business Social Media*, Ch. 31 — planned calendar over random acts of marketing |
| P3_2 hero shot, P3_7 return policy | Platform | Etsy Seller Handbook via module 05 §2.1 — listing quality is a named ranking factor |
| P3_7 shipping ratio warns rather than blocks | Platform | Module 05 §2.5 — 0.4 is a heuristic to refine, not a sourced threshold |
| No conversion threshold | Both, by absence | Module 05 §2.1 names engagement rate as a factor; nothing states a target |

---

## 8. How modules 06 and 09 consume this

Additive. No new statuses, no schema change to `piece_records`.

1. **`Workflow::DecisionRules`** — loads `decision_rules.yml` via the existing
   `KnowledgeBase::RuleSet` loader. Four public methods: `verdict_for(step_id:, result:)`,
   `legal_dispositions(step_id:, verdict:)`, `tier_for(step_id:)`, and
   `validate_disposition!(step_id:, verdict:, disposition:, payload:)`, which raises on an illegal
   combination or a missing mandatory field.
2. **`StepDispatcher#open_gate!`** — writes the computed verdict into the existing
   `context_snapshot` jsonb column. No migration.
3. **The gate-closing path** is one method, shared by the human controller and module 09's
   conductor: `validate_disposition!` first, write the gate second, enqueue third. Neither caller
   may bypass it. This is what makes the matrix an enforcement point rather than a document.
4. **`HumanGatesController#update`** — calls the shared path; renders only the legal buttons,
   splits Reject into Retry / Rewind / Abandon, shows the `rewind_to` target, and drops the
   elapsed-time display per SR4.
5. **`ResumePieceJob`** — on `rewind`, clears the `invalidates` fields and re-enqueues at
   `rewind_to` instead of no-opping.
6. **Module 09's conductor** — calls the same shared path with `reviewer_kind: "agent"`. It cannot
   close a Tier 3 gate (SR12) and cannot close any gate without a resolvable citation (SR11).

---

## 9. Verification

```bash
# 1. Rule file loads and covers every registry step
bin/rails runner '
  rules = KnowledgeBase::RuleSet.load("decision_rules").rules
  reg = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  ids = [ *(reg.dig("phase_1","track_a","steps")||[]), *(reg.dig("phase_1","track_b","steps")||[]),
          *(reg.dig("phase_1","track_c","steps")||[]), *(reg.dig("phase_2","steps")||[]),
          *(reg.dig("phase_3_module_1","steps")||[]) ].map { |s| s["id"] }
  covered = rules["steps"].keys
  # C2 is split into two stages; A_IDEATE is module 01b, not in the registry
  missing = ids - covered - ["C2"]
  puts "registry steps: #{ids.size}"        # expect 38
  puts "decision entries: #{covered.size}"  # expect 40
  puts missing.any? ? "UNCOVERED: #{missing.inspect}" : "all registry steps covered: ok"
'

# 2. The legality matrix forbids the four cases it must
bin/rails runner '
  L = KnowledgeBase::RuleSet.load("decision_rules").rules["legality"]
  checks = {
    "unresolved_input rejects approve" => !L["unresolved_input"].include?("approve"),
    "unresolved_input rejects edit"    => !L["unresolved_input"].include?("edit"),
    "unresolved_perception rejects approve" => !L["unresolved_perception"].include?("approve"),
    "contradicted rejects approve"    => !L["contradicted"].include?("approve"),
    "blocked rejects approve"         => !L["blocked"].include?("approve"),
    "blocked rejects edit"            => !L["blocked"].include?("edit")
  }
  checks.each { |k,v| puts "#{v ? "ok" : "FAIL"}: #{k}" }
'

# 3. A2 is classified as unresolved_input and points at A1
bin/rails runner '
  a2 = KnowledgeBase::RuleSet.load("decision_rules").rules["steps"]["A2"]
  puts "verdicts: #{a2["verdicts"].keys.inspect}"
  puts "rewind_to: #{a2["rewind_to"]}"                       # expect A1
  puts "forbidden: #{a2["on_unresolved_input"]["forbidden"].inspect}"  # expect approve, edit
'

# 4. P2_6 is blocked, not flagged, and cites SR6
bin/rails runner '
  p26 = KnowledgeBase::RuleSet.load("decision_rules").rules["steps"]["P2_6"]
  puts "has flagged verdict: #{p26["verdicts"].key?("flagged")}"   # expect false
  puts "standing_rule: #{p26["on_blocked"]["standing_rule"]}"       # expect SR6
'

# 5. Every rewind_to names a step that exists in this file
bin/rails runner '
  steps = KnowledgeBase::RuleSet.load("decision_rules").rules["steps"]
  bad = steps.flat_map { |id, s|
    Array(s["rewind_to"]).compact.reject { |t| steps.key?(t) }.map { |t| "#{id} -> #{t}" }
  }
  puts bad.any? ? "DANGLING: #{bad.inspect}" : "all rewind targets resolve: ok"
'

# 6. S1 query runs against real data
bin/rails runner '
  bad = HumanGate.where(status: "approved").select { |g|
    %w[unresolved_input unresolved_perception blocked].include?(g.context_snapshot["verdict"])
  }
  puts "illegal approvals: #{bad.size}"   # expect 0
'
```

**Also verify by hand:** open one gate of each verdict class in the review UI and confirm the
button set changes; confirm no elapsed-time or cost figure appears on the gate page (SR4); confirm
a rewind from A2 to A1 clears A3, A4 and A5's session entries and does not touch a committed
`style_specs/<slug>.yml` without a git revert (SR5).

---

## 10. Manifest coverage and open gaps

| Item | Where |
|---|---|
| Verdict taxonomy (6 classes) | §2, `rules.verdicts` |
| Disposition set (5) and legality matrix | §3, `rules.legality` |
| Ten standing rules | §5, `rules.standing_rules` |
| Per-step entries, 40 pause points | `rules.steps` |
| Rewind targets and invalidation graph | §4, per-step `rewind_to` / `invalidates` |
| Budgets, flagged as project convention | §4.4, `rules.budgets` |
| Successful-run definition, decision-quality only | §6, `rules.successful_run` |
| Source attribution per rule | §7, and `authority:` on each step entry |

**Open gaps, deliberate:**

- **G1 — no `Workflow::TrackBSession`.** Module 01c built session carry-forward for Track A only.
  Track B runs pre-piece, so module 06 §3's `open_gate!` early-returns and B0–B7 dispositions are
  currently unrecorded anywhere. SR8 cannot be fully enforced for Track B until this exists. This
  is the one piece of new infrastructure the manual implies and does not provide.
- **G2 — performance thresholds.** Deferred by decision. Lands as S9.
- **G3 — gate count.** The registry marks 17 steps `human_gate: true`; manifest §5 enumerates by
  track and reads as 15. This file treats the registry as canonical and splits C2 into two stages,
  giving 18 pause points across 17 gated steps. The manifest wording is what needs reconciling,
  not the registry.
- **G4 — the review UI shows no verdict.** Module 06 §8.4 renders three buttons unconditionally.
  Enforcing §3 makes them verdict-dependent and splits Reject into three. Under module 09's model
  this UI becomes the fallback path rather than the primary one, but it still needs the change:
  Tier 3 gates and every escalation land there.
