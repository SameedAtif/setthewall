# Module 09 — Agent Orchestration, QA Specialists & the Run Dossier

> **Self-contained.** No new domain rules. This module turns the 38-step pipeline into an
> unattended speculative run that produces one reviewable dossier, with a single human gate at the
> end. It adds no judgment of its own: every automated gate closure is bounded by module 08's
> legality matrix and every QA finding must cite a resolvable rule path.

---

## Contract

**Depends on:** module 00 (`Steps::Base`, `StepResult`, `KnowledgeBase::RuleSet`, `PieceRecord`,
`StyleSpecWriter`), module 00b (`Search::ReasonedRunner` and its `search_calls_made` /
`min_rounds_met` return keys), modules 01–05 (the step classes and their rule files), module 06
(`StepDispatcher`, `StatusMachine`, `HumanGate`), module 07 (`KbEvolution::Applier`), module 08
(`decision_rules.yml`, `Workflow::DecisionRules`).

**Provides:**
- `Workflow::RunMode` — the speculative/committed guard, and the staging-root redirect
- `PipelineRunRecord` model — one row per run, holding mode, status, and dossier
- `Agents::Conductor` — walks the registry, dispatches, routes results to QA, assembles the dossier.
  Contains no judgment.
- `Agents::Base` + `QaFinding` model — the QA agent contract
- Six specialists plus one meta: `ResearchQa`, `AxisQa`, `ImageQa`, `PlacementQa`, `ListingQa`,
  `CustomerSafetyQa`, and `EvidenceQa`
- `Agents::BlindVerifier` — the Tier 2 protocol
- `Agents::Registry` — step → QA agent mapping
- `Dossier::Builder` + `Dossier::MarkdownRenderer` — the report
- `DossierReviewsController` — the single human gate
- `knowledge_base/positioning.yml` — the shop-level positioning claim
- `knowledge_base/rules/qa_rules.yml` — per-agent thresholds and rubrics
- `lib/tasks/run.rake` — `run:speculative`, `run:dossier`, `run:review`, `run:commit`, `run:rerun`

**Consumed by:** you, once a day. Module 07's `WeeklyExport` gains `QaFinding` rows as an
additional signal.

**Must not:** write to `knowledge_base/`, call Etsy's create-listing endpoint, or commit to git
while in speculative mode (SR13); define any domain rule (modules 01–05 own those); close a Tier 3
gate (SR12); or override module 08's legality matrix. QA agents advise. `decision_rules.yml`
decides.

---

## 1. Design decisions

### 1.1 Two run modes, and why this is the load-bearing one

A run is `speculative` or `committed`.

In speculative mode every persistent write is redirected to `tmp/runs/<run_id>/staging/`. A5 and
B7 write spec files there instead of `knowledge_base/style_specs/`. P3_8 writes an Etsy payload
file instead of calling the API. Module 07's applier is disabled entirely. Nothing is committed to
git.

This is what makes deferring the human to the end safe. A speculative run is reversible by
deleting one directory. Everything else in this module rests on that property, so the guard is
enforced at the lowest level rather than by convention:

```ruby
# app/services/workflow/run_mode.rb
module Workflow
  class SpeculativeWriteError < StandardError; end

  class RunMode
    MODES = %w[speculative committed].freeze

    def self.current = Thread.current[:pipeline_run_mode] || "speculative"
    def self.speculative? = current == "speculative"

    def self.with(mode, run_id:)
      raise ArgumentError, "bad mode #{mode}" unless MODES.include?(mode)
      prev, prev_id = Thread.current[:pipeline_run_mode], Thread.current[:pipeline_run_id]
      Thread.current[:pipeline_run_mode], Thread.current[:pipeline_run_id] = mode, run_id
      yield
    ensure
      Thread.current[:pipeline_run_mode], Thread.current[:pipeline_run_id] = prev, prev_id
    end

    # Every writer asks for its root through here. Nothing hardcodes KB_ROOT any more.
    def self.write_root
      speculative? ? staging_root : Pipeline::KB_ROOT
    end

    def self.staging_root
      id = Thread.current[:pipeline_run_id] or raise SpeculativeWriteError, "no run_id in scope"
      Rails.root.join("tmp", "runs", id, "staging").tap(&:mkpath)
    end

    # Called by anything that must never run speculatively (Etsy publish, git commit, KB applier).
    def self.require_committed!(what)
      return unless speculative?
      raise SpeculativeWriteError,
            "#{what} attempted during a speculative run. Approve the dossier first."
    end
  end
end
```

**Defaulting to speculative is deliberate.** If the thread-local is unset — a console session, a
stray job, a test — the safe mode is the one that applies. Committed mode has to be asked for.

Three call sites change, and only three:

| Where | Change |
|---|---|
| `KnowledgeBase::StyleSpecWriter` / `SceneSpecWriter` | root becomes `Workflow::RunMode.write_root` |
| `Steps::Phase3::PublishAndLog` | `RunMode.require_committed!("Etsy publish")` before the adapter call |
| `KbEvolution::Applier` (module 07 §6.3) | `RunMode.require_committed!("knowledge base write")` at entry |

### 1.2 The conductor never judges

`Agents::Conductor` dispatches steps, hands results to QA, applies module 08's matrix to the
resulting verdict, and records what happened. It never forms an opinion about a step's output.

Why: if the thing that decides the order also decides the outcomes, there is nowhere to audit. Two
components with narrow jobs are checkable. One component that does both is a black box that
happens to produce plausible logs.

### 1.3 QA agents advise; the rule file decides

A QA agent returns findings, not dispositions. A finding is a citation plus a claim plus a
severity. The conductor maps findings to a verdict, then asks `Workflow::DecisionRules` which
dispositions that verdict permits, then picks from that set.

This is the difference between an agent that is bounded and an agent that is asked to be careful.
Asking a model to be careful is not a control.

### 1.4 Blind verification, no tie-breaker

Tier 2 gates get a second agent that receives the step input and the cited rule, never the
proposal. Agreement closes the gate. Disagreement escalates to the dossier.

There is deliberately no third agent. Proposer and verifier run the same model on overlapping
context, so their errors correlate: agreement is weak evidence and disagreement is the informative
signal. A tie-breaker converts the one real error detector into a majority vote among correlated
judges. If you only implement one thing from this module carefully, make it this.

### 1.5 Positioning is shop-level, not per-listing

Module 05 §6.7's description prompt takes a variable it labels "Style spec's positioning target",
but the style-spec schema in module 00 §7.1 has nine axes and no positioning field. `P3_6` fetches
it from context, so it hard-fails unless a human types one in. This module gives it a real source
in `knowledge_base/positioning.yml`, defined once and read by every listing.

---

## 2. `knowledge_base/positioning.yml`

Not a rule table. One file, one claim, read by P3_6 and by the dossier's rationale section.

```yaml
# ---
# source: Project positioning, set by the shop owner
# citation: |
#   The Paradox of Choice — the central thesis: expanded choice increases the effort a decision
#   requires, makes mistakes more likely, and makes the psychological consequences of mistakes
#   more severe; and the chooser/picker distinction, where a picker grabs from what rushes past
#   while a chooser reflects on criteria before deciding.
#   This Is Marketing, Ch. 4 and Ch. 8 — the smallest viable market; positioning means standing
#   for something rather than everything.
# doc: docs/source_knowledge_base/
# last_verified: "TODO — set on first run"
# ---

meta:
  volatility: static
  note: >
    This file exists because P3_6 requires a positioning_target and nothing upstream produced one.
    It is deliberately short. If it grows into a brand document, it has stopped being a rule file.

positioning:
  problem: >
    Choosing art for a wall is a high-effort decision with no clear criteria. The buyer faces
    unlimited options, cannot tell which would work in their actual room, and has no way to know
    whether a choice was right until it is hanging. So the decision gets deferred indefinitely.

  change_we_make: >
    We convert an open-ended choice into a decided one. Each listing shows a specific piece, in a
    specific kind of room, placed correctly — and says why that placement is right.

  who_it_is_for: >
    Someone who wants art on their wall and has stalled on choosing it. Not a collector building a
    collection; a person who wants the wall finished and wants to stop deliberating about it.

  what_we_do_not_claim:
    - "for everyone"
    - "for any room"
    - "suits all styles"

  the_three_promises:
    - "Here is the art."
    - "Here is where it goes."
    - "Here is how to hang it."

  # P3_6 interpolates this. It must survive the step's own "for everyone" rejection check.
  positioning_target: >
    Someone who has been putting off choosing art because they cannot picture what will work —
    shown one piece, in a room like theirs, hung at the right height.

  grounding_note: >
    The third promise is why Phase 2 §5's customer-education content (the no-holes planning
    method p. 57, hanging hardware matched to real weight p. 40-41, conservation glass) is part of
    the product rather than a footnote. That is also why Phase 2 §6 Limitation 4 — anything from
    §5 that reaches a customer must be fact-checked — becomes a QA agent in §5.6 below.
```

---

## 3. Schema additions

Two tables. Neither touches `piece_records`.

```ruby
# db/migrate/XXXXXX_create_pipeline_run_records.rb
class CreatePipelineRunRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :pipeline_run_records do |t|
      t.string   :run_id,   null: false, index: { unique: true }  # e.g. "run_20260902_a3f1"
      t.string   :mode,     null: false, default: "speculative"   # speculative | committed
      t.string   :status,   null: false, default: "running"
      # running | awaiting_dossier_review | approved | rerunning | committed | abandoned | failed
      t.references :piece_record, foreign_key: true               # null for Track A/B-only runs
      t.string   :style_slug
      t.string   :scene_spec_id
      t.string   :kb_version, null: false
      t.jsonb    :step_results,  null: false, default: []
      t.jsonb    :escalations,   null: false, default: []
      t.text     :dossier_markdown
      t.jsonb    :dossier_data,  null: false, default: {}
      t.text     :reviewer_notes
      t.datetime :started_at
      t.datetime :dossier_ready_at
      t.datetime :reviewed_at
      t.timestamps
    end
  end
end
```

```ruby
# db/migrate/XXXXXX_create_qa_findings.rb
class CreateQaFindings < ActiveRecord::Migration[8.0]
  def change
    create_table :qa_findings do |t|
      t.references :pipeline_run_record, null: false, foreign_key: true
      t.string  :step_id,   null: false
      t.string  :agent_id,  null: false     # research_qa | axis_qa | image_qa | ...
      t.string  :role,      null: false, default: "proposer"   # proposer | verifier
      t.string  :severity,  null: false     # pass | advisory | blocking
      t.text    :claim,     null: false
      t.jsonb   :citations, null: false, default: []  # [{ rule_path:, quote_key:, resolves: }]
      t.jsonb   :payload,   null: false, default: {}
      t.boolean :citations_resolved                    # set by EvidenceQa, null until checked
      t.timestamps
    end
    add_index :qa_findings, [:pipeline_run_record_id, :step_id]
  end
end
```

`HumanGate` gains two columns so module 08's SR11/SR12 are enforceable:

```ruby
# db/migrate/XXXXXX_add_reviewer_kind_to_human_gates.rb
class AddReviewerKindToHumanGates < ActiveRecord::Migration[8.0]
  def change
    add_column :human_gates, :reviewer_kind, :string, null: false, default: "human"
    add_column :human_gates, :citations, :jsonb, null: false, default: []
    add_column :human_gates, :verdict, :string
    add_index  :human_gates, :reviewer_kind
    change_column_null :human_gates, :piece_record_id, true   # G1: pre-piece gates
  end
end
```

**The `piece_record_id` null change is the fix for module 08's G1.** Module 06 §3's `open_gate!`
early-returns when `piece` is nil, so Track A and Track B gates were never recorded anywhere. With
the column nullable, `open_gate!` drops the early return and pre-piece gates get rows like every
other gate. Remove this line from `StepDispatcher#open_gate!`:

```ruby
return if @piece.nil?   # DELETE — pre-piece gates are recorded now
```

---

## 4. `Agents::Base` — the QA agent contract

Every specialist inherits this. The contract is deliberately narrow: given a step result and its
inputs, return findings. No dispositions, no next-step opinions.

```ruby
# app/agents/base.rb
module Agents
  Finding = Struct.new(:severity, :claim, :citations, :payload, keyword_init: true) do
    def blocking? = severity == "blocking"
    def advisory? = severity == "advisory"
    def pass?     = severity == "pass"
  end

  class Base
    class << self
      attr_reader :agent_id, :covers
      def agent(id:, covers:)
        @agent_id = id
        @covers   = Array(covers)
      end
    end

    def initialize(run:, step_id:, result:, context:, role: "proposer")
      @run, @step_id, @result, @context, @role = run, step_id, result, context, role
    end

    def self.call(...) = new(...).call

    def call
      findings = Array(evaluate)
      raise "#{self.class.agent_id} returned no findings for #{@step_id}" if findings.empty?
      findings.each { |f| persist!(f) }
      findings
    end

    private

    # Subclasses implement. Must return one or more Finding.
    def evaluate = raise NotImplementedError

    # Helpers available to every specialist.
    def rules(name) = KnowledgeBase::RuleSet.load(name)
    def qa_rules    = rules("qa_rules").rules.fetch(self.class.agent_id)

    def pass(claim, citations)      = Finding.new(severity: "pass", claim:, citations:, payload: {})
    def advisory(claim, citations, payload = {}) =
      Finding.new(severity: "advisory", claim:, citations:, payload:)
    def blocking(claim, citations, payload = {}) =
      Finding.new(severity: "blocking", claim:, citations:, payload:)

    # A citation is a path into a rule file, not a sentence. EvidenceQa re-resolves these.
    def cite(rule_path, claim: nil)
      { "rule_path" => rule_path, "claim" => claim }
    end

    def persist!(f)
      QaFinding.create!(
        pipeline_run_record: @run, step_id: @step_id, agent_id: self.class.agent_id,
        role: @role, severity: f.severity, claim: f.claim,
        citations: f.citations, payload: f.payload
      )
    end
  end
end
```

**On `cite`.** A `rule_path` is a dotted path such as
`mood.rules.validation.rule` or `coverage_cap.rules.cap.default_max_fraction`. It resolves through
`KnowledgeBase::RuleSet` or it does not. Free-text citations are not accepted, because a model can
write a plausible page number as easily as a real one.

---

## 5. The specialists

Seven agents. Each covers a set of steps and is bound to specific rule files. The mapping lives in
`Agents::Registry` (§5.8) so that adding a step never means hunting for which agent should see it.

### 5.1 `ResearchQa` — A_IDEATE, A0, A1

Bound to `00b`'s search accounting, `ideation_constraints.yml`, and `reference_set_criteria.yml`.

```ruby
# app/agents/research_qa.rb
module Agents
  class ResearchQa < Base
    agent id: "research_qa", covers: %w[A_IDEATE A0 A1]

    def evaluate
      d = @result.data || {}
      findings = []

      # 1. Did search actually happen? (module 00b's whole purpose)
      if d.key?(:min_rounds_met) || d.key?("min_rounds_met")
        met   = d[:min_rounds_met] || d["min_rounds_met"]
        calls = d[:search_calls_made] || d["search_calls_made"]
        findings << if met
          pass("Search methodology floor met (#{calls} live calls).",
               [cite("qa_rules.rules.research_qa.search_floor")])
        else
          blocking("Search stopped short of the declared minimum (#{calls} calls). " \
                   "Findings are thinner than the methodology requires.",
                   [cite("qa_rules.rules.research_qa.search_floor")],
                   { search_calls_made: calls })
        end
      end

      # 2. Independent-source bar — two sources, not one opinion
      findings.concat(check_source_independence(d))

      # 3. Promotional framing — vendor blogs presenting their own tooling as trend evidence
      findings.concat(check_promotional_framing(d))

      # 4. A0 breadth — fragmentation is unresolved_input, never a pick
      if @step_id == "A0" && (d["breadth_assessment"] || d[:breadth_assessment]) == "fragments_into_substyles"
        findings << blocking(
          "Style fragments into distinct sub-themes. This is not one coherent style, and the " \
          "agent's single_recommended_focus is a narrowing proposal, not an answer.",
          [cite("decision_rules.rules.steps.A0.on_unresolved_input")],
          { recommended_focus: d["single_recommended_focus"] }
        )
      end

      # 5. A1 mood clustering — cheaper to catch here than after A2 scores
      clusters = Array(d["mood_clusters_found"] || d[:mood_clusters_found])
      if @step_id == "A1" && clusters.size > 1
        findings << blocking(
          "Reference set spans #{clusters.size} mood clusters. Narrowing now is cheaper than " \
          "discovering the same split after A2's full scoring pass.",
          [cite("decision_rules.rules.steps.A1.on_unresolved_input")],
          { clusters: clusters.map { |c| c["label"] } }
        )
      end

      findings
    end

    private

    def check_source_independence(d)
      images = Array(d.dig("candidates", "images") || d["images"])
      return [] if images.empty?
      min = qa_rules.dig("source_independence", "min_sources_per_item")
      weak = images.select { |i| Array(i["attributing_sources"]).size < min }
      return [pass("Every item carries #{min}+ independent attributing sources.",
                   [cite("reference_set_criteria.rules.image_requirements")])] if weak.empty?
      [advisory("#{weak.size} item(s) attributed by fewer than #{min} independent sources.",
                [cite("reference_set_criteria.rules.image_requirements")],
                { weak_count: weak.size })]
    end

    def check_promotional_framing(d)
      phrases = Array(rules("ideation_constraints").rules
                        .dig("promotional_language_indicators", "phrases"))
      blob = d.to_s.downcase
      hits = phrases.select { |p| blob.include?(p.downcase) }
      return [] if hits.empty?
      [advisory("Source language matches promotional-framing patterns (#{hits.join(', ')}). " \
                "Treat the trend claim as one source's marketing, not neutral evidence.",
                [cite("ideation_constraints.rules.promotional_language_indicators")],
                { matched: hits })]
    end
  end
end
```

### 5.2 `AxisQa` — A2, A3, A4, B1–B6

The most important agent in the module, because it is the one an unconstrained model gets wrong.
Its job is largely to *refuse*.

```ruby
# app/agents/axis_qa.rb
module Agents
  class AxisQa < Base
    agent id: "axis_qa", covers: %w[A2 A3 A4 B1 B2 B3 B4 B5 B6]

    def evaluate
      d = @result.data || {}
      r = d["result"] || d
      case @step_id
      when "A2" then mood(r)
      when "A3" then content_type(r)
      when "A4" then frame_form(r)
      when "B3" then room_type(r)
      when "B6" then color_role(d)
      else           borderline(r)
      end
    end

    private

    # A2 is the canonical unresolved_input case. Do not force a call.
    def mood(r)
      cites = [cite("mood.rules.scoring.mixed_result"), cite("mood.rules.validation")]
      return [blocking(
        "Mood scorecard is mixed. Per the rule, a mixed scorecard means the reference set is not " \
        "focused enough — narrow it and return to A1. Do NOT pick the closer of the two moods.",
        cites)] if r["mood"] == "mixed"

      markers = r["markers_supporting_chosen_mood"].to_i
      images  = r["clearly_supporting_images"].to_i
      need_m  = qa_rules.dig("a2", "required_markers")
      need_i  = qa_rules.dig("a2", "required_images")
      return [blocking(
        "Mood proposed as #{r['mood']} but the validation bar was not met " \
        "(#{markers}/#{need_m} markers, #{images}/#{need_i} clearly supporting images).",
        cites, { markers:, images: })] if markers < need_m || images < need_i

      [pass("Mood #{r['mood']} supported by #{images} images across #{markers} of the four markers.",
            cites)]
    end

    def content_type(r)
      c = [cite("content_type.rules.determination")]
      return [blocking(
        "Frame-contour cross-check failed (predicted #{r['predicted_contour']}, observed " \
        "#{r['observed_contour']}). Per the rule, a contour mismatch means the content-type call " \
        "is probably wrong.", c)] unless r["contour_cross_check_passed"]
      [pass("Content type #{r['content_type']} passes the contour cross-check.", c)]
    end

    def frame_form(r)
      c = [cite("frame_form.rules.determination.tiebreaker")]
      return [advisory("Framing was mixed across references; resolved by the mood tiebreaker. " \
                       "Any later change to mood invalidates this.", c)] if r["consistency"] == "mixed"
      [pass("Frame form #{r['frame_form']} was consistent across references.", c)]
    end

    # B3 has no safe default — this is unresolved_perception, and the escalation is mandatory.
    def room_type(r)
      c = [cite("borderline_defaults.rules.room_type")]
      return [blocking(
        "Room type came back ambiguous and this axis has no safe default: the three eye-level " \
        "formulas are not interchangeable, so a wrong read produces a plausible-looking but " \
        "wrong composite at P2_6.", c)] if r["room_type"] == "ambiguous"
      [pass("Room type #{r['room_type']} read unambiguously.", c)]
    end

    def color_role(d)
      c = [cite("color_role_observation.rules"), cite("decision_rules.rules.steps.B6")]
      conflicts = Array(d["conflicts"])
      return [blocking("Cross-check conflicts: #{conflicts.join('; ')}. Resolve explicitly rather " \
                       "than defaulting to whichever was decided first.", c)] if conflicts.any?
      if d["override_pending"]
        return [blocking("The minimalist_modern default (line_only, p. 97) overrides the observed " \
                         "candidate. This is a catalog-strategy call the agent cannot make.", c)]
      end
      [pass("Colour role #{d['color_role']} clears the B6 cross-check.", c)]
    end

    # B1/B2/B4 — a silently-applied default must be visible at B7 (SR10).
    def borderline(r)
      c = [cite("borderline_defaults.rules")]
      return [advisory("Axis was borderline; the safe-fail default was applied. This must surface " \
                       "at B7 before the scene is locked.", c, { resolved_by_default: true })] if r["borderline"]
      [pass("Axis read unambiguously.", c)]
    end
  end
end
```

### 5.3 `ImageQa` — C1, C2 stage 1, P3_1b

**Read this one carefully, because it is the one place the knowledge base is silent.** Nothing in
`generation_constraints.yml`, `reference_set_criteria.yml`, or the arrangement books defines what
makes a generated image good. So this agent does not judge merit. It judges **conformance**: does
the candidate read as the locked axes, and does it sit inside the visual range of the reference set
A1 curated?

Merit stays at C2 stage 2, which is Tier 3.

```ruby
# app/agents/image_qa.rb
module Agents
  class ImageQa < Base
    agent id: "image_qa", covers: %w[C1 C2_finalists P3_1b]

    def evaluate
      urls = candidate_urls
      return [blocking("No candidate images to evaluate.",
                       [cite("qa_rules.rules.image_qa.scope")])] if urls.empty?

      result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                      .with_schema(Schemas::Qa::ImageConformanceSchema)
                      .ask(prompt_text, with: urls + reference_urls).content

      findings = []
      result["per_image"].each do |img|
        mismatches = Array(img["axis_mismatches"])
        findings << if mismatches.empty?
          pass("Candidate #{img['index']} conforms to the locked axes.",
               [cite("qa_rules.rules.image_qa.conformance_axes")])
        else
          advisory("Candidate #{img['index']} does not read as #{mismatches.join(', ')}.",
                   [cite("qa_rules.rules.image_qa.conformance_axes")],
                   { index: img["index"], mismatches: mismatches })
        end
      end

      # Hard constraint checks — these ARE in the rule file
      neg = Array(rules("generation_constraints").rules.dig("constraints", "negative_prompt"))
      violations = Array(result["constraint_violations"])
      if violations.any?
        findings << blocking("Negative-prompt constraints violated: #{violations.join(', ')}.",
                             [cite("generation_constraints.rules.constraints.negative_prompt")],
                             { violations:, declared: neg })
      end

      conforming = result["per_image"].count { |i| Array(i["axis_mismatches"]).empty? }
      if conforming.zero?
        findings << blocking(
          "No candidate in the batch conforms to the locked axes. Regenerating is the correct " \
          "move, not culling the least-wrong one.",
          [cite("decision_rules.rules.steps.C2_finalists.on_unresolved_input")])
      end
      findings
    end

    private

    def prompt_text
      <<~P
        You are checking CONFORMANCE, not quality. Do not judge whether an image is good,
        beautiful, or marketable. Judge only whether it matches the locked specification.

        Locked axes for this style and scene:
        - mood: #{@run.piece_record&.mood}
        - content_type: #{@run.piece_record&.content_type}
        - color_role: #{@run.piece_record&.color_role}
        - frame_form: #{@run.piece_record&.frame_form}
        - room_shape constraint: #{@run.piece_record&.room_shape}

        The final images in this set are the curated REFERENCE set for this style. Candidates
        should sit inside their visual range.

        For each candidate, list which of the locked axes it fails to read as, using those exact
        axis names. An empty list means it conforms. Also report any violation of these
        constraints: #{Array(rules('generation_constraints').rules.dig('constraints', 'negative_prompt')).join(', ')}.

        Aesthetic preference is out of scope. If you find yourself wanting to say one image is
        nicer than another, do not say it.
      P
    end

    def candidate_urls
      case @step_id
      when "C1", "C2_finalists" then Array(@run.piece_record&.candidate_urls)
      when "P3_1b" then (@run.piece_record&.photos || {}).values.compact
      else []
      end
    end

    def reference_urls
      Array(@run.dossier_data.dig("A1", "curated_images")).first(4)
    end
  end
end
```

### 5.4 `PlacementQa` — P2_1 through P2_6

The strongest agent, because almost everything it checks is arithmetic against a page citation. It
re-derives rather than trusting the step's own report.

```ruby
# app/agents/placement_qa.rb
module Agents
  class PlacementQa < Base
    agent id: "placement_qa", covers: %w[P2_1 P2_2a P2_2b P2_2c P2_2d P2_2e P2_3 P2_4 P2_4b P2_5 P2_6]

    def evaluate
      @step_id == "P2_6" ? composite : rule_lookup
    end

    private

    def composite
      m = (@result.data || {})["measurements"] || {}
      ppi = m["pixels_per_inch"].to_f
      findings = []

      # Coverage cap — p. 51. Binary, and NOT overridable (module 08 SR6).
      cf  = m["coverage_fraction"].to_f
      cap = rules("coverage_cap").rules.dig("cap", "default_max_fraction").to_f
      if cf > cap && cf < 0.95
        findings << blocking(
          "Coverage fraction #{cf.round(3)} falls in the forbidden mid-band. Coverage is binary: " \
          "stay under two-thirds or commit fully maximalist. A partial overreach reads as a mistake.",
          [cite("coverage_cap.rules.cap")], { coverage_fraction: cf })
      else
        findings << pass("Coverage fraction #{cf.round(3)} is outside the forbidden mid-band.",
                         [cite("coverage_cap.rules.cap")])
      end

      # Eye-level drop — p. 63. Most people hang too high.
      drop = rules("eye_level").rules.dig("general_drop", "formula_inches").to_f.abs
      unless m["drop_applied_inches"].to_f.between?(drop - 0.6, drop + 0.6)
        findings << blocking(
          "General eye-level drop of #{drop}\" was not applied (found " \
          "#{m['drop_applied_inches']}\"). Hanging too high is the most common placement mistake.",
          [cite("eye_level.rules.general_drop")])
      end

      # Furniture gap — p. 63, seated rooms only
      if @run.piece_record&.room_type == "seated_room" && ppi.positive?
        gap = m["furniture_gap_px"].to_f / ppi
        findings << if gap.between?(8.0, 10.0)
          pass("Furniture gap #{gap.round(1)}\" sits in the 8-10\" band.",
               [cite("spacing.rules")])
        else
          blocking("Furniture gap is #{gap.round(1)}\", outside the 8-10\" band. The group must " \
                   "relate to the furniture below without crowding it.",
                   [cite("spacing.rules")], { gap_inches: gap.round(2) })
        end
      end

      # Group width vs furniture — p. 63
      if m["group_width_px"] && m["furniture_width_px"]
        ratio = m["group_width_px"].to_f / m["furniture_width_px"].to_f
        unless ratio.between?(0.5, 1.0)
          findings << blocking(
            "Group width is #{(ratio * 100).round}% of the furniture below. It must be no wider " \
            "than the furniture and at least half its length.",
            [cite("spacing.rules")], { ratio: ratio.round(3) })
        end
      end
      findings
    end

    # For lookup steps, re-derive the answer from the rule file and compare.
    def rule_lookup
      expected = Steps::Phase2::RuleReference.derive(@step_id, @run.piece_record)
      actual   = (@result.data || {}).slice(*expected.keys.map(&:to_s))
      diffs    = expected.reject { |k, v| actual[k.to_s].to_s == v.to_s }
      c = [cite(Steps::Phase2::RuleReference.rule_path_for(@step_id))]
      return [pass("#{@step_id} output matches the rule table.", c)] if diffs.empty?
      [blocking("#{@step_id} output diverges from the rule table: " \
                "#{diffs.map { |k, v| "#{k} should be #{v}" }.join('; ')}.", c, { diffs: })]
    end
  end
end
```

> `Steps::Phase2::RuleReference` is a small read-only helper this module adds: given a step id and
> a piece, it returns the values the rule tables dictate, and the rule path they came from. It
> re-reads the same YAML the step read. An agent that only checks whether the step's own output is
> self-consistent checks nothing.

### 5.5 `ListingQa` — P3_2 through P3_7

```ruby
# app/agents/listing_qa.rb
module Agents
  class ListingQa < Base
    agent id: "listing_qa", covers: %w[P3_2 P3_3 P3_4 P3_5 P3_6 P3_7]

    def evaluate
      case @step_id
      when "P3_3" then title
      when "P3_4" then tags
      when "P3_6" then description
      when "P3_7" then policy
      else [pass("#{@step_id} produced output within its documented constraints.",
                 [cite("etsy_search_mechanism.rules.ranking_factors")])]
      end
    end

    private

    def title
      t = (@result.data || {})["title"].to_s
      c = [cite("etsy_titles.rules")]
      first_six = t.split.first(6).join(" ")
      return [advisory("First six words (#{first_six.inspect}) may not identify the piece on a " \
                       "mobile search result. Etsy states word order does not affect ranking, so " \
                       "leading with the clearest descriptor costs nothing.", c)] if first_six.length < 20
      [pass("Title leads with a literal descriptor in the first six words.", c)]
    end

    def tags
      tags = Array((@result.data || {})["tags"])
      c = [cite("etsy_tags.rules.slot_count"), cite("etsy_tags.rules.phrase_style")]
      f = []
      f << blocking("Only #{tags.size} of 13 tag slots filled. Each slot is a separate " \
                    "query-match opportunity.", c) if tags.size < 13
      single = tags.count { |t| t.to_s.split.size == 1 }
      f << advisory("#{single} single-word tags. Multi-word long-tail phrases outperform single " \
                    "words.", c) if single > qa_rules.dig("tags", "max_single_word")
      f << pass("13 tags, predominantly multi-word phrases.", c) if f.empty?
      f
    end

    def description
      d = (@result.data || {})["description"] || {}
      claim = d["positioning_claim"].to_s
      c = [cite("positioning.positioning.what_we_do_not_claim"),
           cite("etsy_antipatterns.rules")]
      f = []

      # This Is Marketing — a universal audience is no audience.
      if claim.downcase.match?(/\b(everyone|anyone|anybody|all(?:\s+kinds\s+of)?)\b/)
        f << blocking("Positioning claim is universal (#{claim.inspect}). A listing claiming " \
                      "everyone claims no one.", c)
      end

      # New: consistency against the shop-level claim, which per-listing checks cannot catch.
      target = rules("positioning").rules.dig("positioning", "positioning_target")
      if claim.present? && !consistent_with?(claim, target)
        f << advisory("Positioning claim drifts from the shop-level claim in positioning.yml. " \
                      "Two listings in one style should not describe different buyers.", c,
                      { claim:, shop_claim: target })
      end
      f << pass("Positioning claim is specific and consistent with positioning.yml.", c) if f.empty?
      f
    end

    def policy
      d = @context || {}
      item = d[:item_price_usd].to_f
      ship = d[:shipping_price_usd].to_f
      c = [cite("etsy_policy.rules"), cite("etsy_antipatterns.rules")]
      return [advisory("Shipping is #{(ship / item * 100).round}% of item price. This approaches " \
                       "the low-price-plus-inflated-shipping pattern Etsy's ranking works against. " \
                       "The 0.4 threshold is a heuristic, so this warns rather than blocks.",
                       c, { ratio: (ship / item).round(3) })] if item.positive? && ship / item > 0.4
      [pass("Return policy set and shipping ratio within the heuristic band.", c)]
    end

    def consistent_with?(claim, target)
      RubyLLM.chat(model: Pipeline::TEXT_MODEL)
             .with_schema(Schemas::Qa::ConsistencySchema)
             .ask("Do these describe the same buyer? Answer strictly.\nA: #{target}\nB: #{claim}")
             .content["same_buyer"]
    end
  end
end
```

### 5.6 `CustomerSafetyQa` — P3_6, P3_8

Phase 2 §6 Limitation 4 states that anything from §5 reaching a customer must be fact-checked,
because an agent summarising the doc can smooth over details that matter when someone hangs a real,
heavy piece on a real wall. Under the positioning in §2, the third promise ("here is how to hang
it") makes that content part of the product. So it gets its own agent.

```ruby
# app/agents/customer_safety_qa.rb
module Agents
  class CustomerSafetyQa < Base
    agent id: "customer_safety_qa", covers: %w[P3_6 P3_8]

    WATCHED = %w[hanger sawtooth anchor screw wire hook weight lbs kg
                 conservation uv glass humidity bathroom kitchen].freeze

    def evaluate
      text = customer_facing_text.downcase
      hits = WATCHED.select { |w| text.include?(w) }
      c = [cite("hanging_hardware.rules"), cite("safekeeping.rules")]
      return [pass("No hardware, weight-rating, or conservation claims in customer-facing copy.",
                   c)] if hits.empty?

      claims = extract_claims(customer_facing_text)
      unverified = claims.reject { |cl| verifiable_against_rules?(cl) }
      return [pass("#{claims.size} hardware/conservation claim(s), all traceable to the rule files.",
                   c)] if unverified.empty?

      [blocking(
        "#{unverified.size} customer-facing hardware or conservation claim(s) not traceable to " \
        "the rule files: #{unverified.first(3).join(' | ')}. Per Phase 2 §6 Limitation 4 these " \
        "must be fact-checked before publishing — a wrong weight rating is a physical hazard.",
        c, { unverified: })]
    end
  end
end
```

### 5.7 `EvidenceQa` — meta, runs over every finding

The one agent that does not look at pipeline output. It re-resolves every citation every other
agent produced. SR11 is enforced here, independently, because self-reported grounding is not
grounding.

```ruby
# app/agents/evidence_qa.rb
module Agents
  class EvidenceQa
    def self.call(run:)
      run.qa_findings.where(citations_resolved: nil).find_each do |finding|
        ok = Array(finding.citations).all? { |c| resolves?(c["rule_path"]) }
        finding.update!(citations_resolved: ok)
      end
      run.qa_findings.where(citations_resolved: false)
    end

    # A rule_path is "<file>.<dotted.key.path>". It resolves or it does not.
    def self.resolves?(path)
      return false if path.blank?
      file, *keys = path.to_s.split(".")
      data = KnowledgeBase::RuleSet.load(file).to_h
      keys.reduce(data) { |acc, k| acc.is_a?(Hash) ? acc[k] : nil }.present?
    rescue StandardError
      false
    end
  end
end
```

### 5.8 `Agents::Registry`

```ruby
# app/agents/registry.rb
module Agents
  class Registry
    SPECIALISTS = [ResearchQa, AxisQa, ImageQa, PlacementQa, ListingQa, CustomerSafetyQa].freeze

    def self.for(step_id) = SPECIALISTS.select { |a| a.covers.include?(step_id) }

    # Fail loudly rather than letting a step slip through unreviewed.
    def self.validate_coverage!
      gated = Workflow::DecisionRules.gated_step_ids
      uncovered = gated.reject { |id| self.for(id).any? }
      raise "Steps with no QA agent: #{uncovered.inspect}" if uncovered.any?
      true
    end
  end
end
```

---

## 6. `Agents::BlindVerifier` — the Tier 2 protocol

```ruby
# app/agents/blind_verifier.rb
module Agents
  class BlindVerifier
    Outcome = Struct.new(:agreed, :verifier_findings, :divergence, keyword_init: true)

    def self.call(run:, step_id:, result:, context:, proposer_findings:)
      # The verifier sees the step input and the cited rules. It never sees proposer_findings.
      verifier_findings = Registry.for(step_id).flat_map do |klass|
        klass.call(run: run, step_id: step_id, result: result, context: context, role: "verifier")
      end

      p_sev = worst(proposer_findings)
      v_sev = worst(verifier_findings)
      Outcome.new(
        agreed: p_sev == v_sev,
        verifier_findings: verifier_findings,
        divergence: p_sev == v_sev ? nil : { proposer: p_sev, verifier: v_sev }
      )
    end

    RANK = { "pass" => 0, "advisory" => 1, "blocking" => 2 }.freeze
    def self.worst(findings) = findings.max_by { |f| RANK.fetch(f.severity, 0) }&.severity || "pass"
  end
end
```

**Do not add a tie-breaker.** See §1.4. Disagreement escalates to the dossier unresolved, and that
is the intended behaviour rather than a limitation.

---

## 7. `Agents::Conductor`

```ruby
# app/agents/conductor.rb
module Agents
  class Conductor
    def self.run_speculative(style_slug:, scene_spec_id:)
      run = PipelineRunRecord.create!(
        run_id: "run_#{Date.current.strftime('%Y%m%d')}_#{SecureRandom.hex(2)}",
        mode: "speculative", status: "running",
        style_slug: style_slug, scene_spec_id: scene_spec_id,
        kb_version: Workflow::PreflightCheck.kb_version, started_at: Time.current
      )
      Workflow::RunMode.with("speculative", run_id: run.run_id) { new(run).call }
      run
    end

    def initialize(run) = @run = run

    def call
      Registry.validate_coverage!
      step_id = Workflow::PipelineRun.first_step_for(@run)

      while step_id
        outcome = execute(step_id)
        case outcome[:action]
        when :advance  then step_id = Workflow::PipelineRun.next_step_after(step_id, piece)
        when :rewind   then step_id = outcome[:rewind_to]
        when :retry    then step_id = step_id
        when :escalate then escalate!(step_id, outcome); step_id = skip_or_stop(step_id)
        when :halt     then break
        end
      end

      EvidenceQa.call(run: @run)
      @run.update!(dossier_markdown: Dossier::Builder.call(run: @run),
                   status: "awaiting_dossier_review", dossier_ready_at: Time.current)
    end

    private

    def piece = @run.piece_record

    def execute(step_id)
      context = Context::Assembler.for(step_id, @run)
      result  = Workflow::StepDispatcher.call(step_id:, piece:, context:)
      record_step!(step_id, result)

      tier = Workflow::DecisionRules.tier_for(step_id)
      return { action: :advance } if result.ok? && tier == 1 && !gated?(step_id)
      return { action: :escalate, reason: "tier_3_gate" } if tier == 3

      findings = Registry.for(step_id).flat_map do |klass|
        klass.call(run: @run, step_id:, result:, context:, role: "proposer")
      end

      if tier == 2
        v = BlindVerifier.call(run: @run, step_id:, result:, context:, proposer_findings: findings)
        return { action: :escalate, reason: "verifier_divergence", divergence: v.divergence } unless v.agreed
      end

      close_gate(step_id, result, findings)
    end

    # The ONLY place a disposition is chosen. Bounded by module 08 at every step.
    def close_gate(step_id, result, findings)
      verdict = Workflow::DecisionRules.verdict_for(step_id:, result:, findings:)
      legal   = Workflow::DecisionRules.legal_dispositions(step_id:, verdict:)

      disposition =
        if findings.any?(&:blocking?) then legal.include?("rewind") ? "rewind" : "retry"
        elsif findings.any?(&:advisory?) && legal.include?("approve") then "approve"
        elsif legal.include?("approve") then "approve"
        else return { action: :escalate, reason: "no_legal_agent_disposition", verdict: }
        end

      return { action: :escalate, reason: "budget_exhausted" } if budget_exhausted?(step_id, disposition)

      Workflow::DecisionRules.validate_disposition!(
        step_id:, verdict:, disposition:, reviewer_kind: "agent",
        payload: { citations: findings.flat_map(&:citations),
                   acceptance_note: acceptance_note(findings),
                   notes: findings.map(&:claim).join(" | ") }
      )
      Workflow::GateCloser.call(run: @run, step_id:, verdict:, disposition:,
                                reviewer_kind: "agent", findings:)

      case disposition
      when "approve", "edit" then { action: :advance }
      when "retry"           then { action: :retry }
      when "rewind"          then { action: :rewind,
                                    rewind_to: Workflow::DecisionRules.rewind_to(step_id) }
      else { action: :escalate, reason: disposition }
      end
    end

    def acceptance_note(findings)
      adv = findings.select(&:advisory?)
      return nil if adv.empty?
      "Accepted #{adv.size} advisory finding(s): #{adv.map(&:claim).join(' | ')}"
    end

    def budget_exhausted?(step_id, disposition)
      return false unless %w[retry rewind].include?(disposition)
      Workflow::DecisionRules.budget_exhausted?(run: @run, step_id:, disposition:)
    end

    def escalate!(step_id, outcome)
      @run.escalations << outcome.merge(step_id: step_id, at: Time.current.iso8601)
      @run.save!
    end
  end
end
```

**What the conductor does not do.** It does not decide whether a mood reading is right, whether an
image is good, or whether a title is strong. Every one of those is a QA finding with a citation,
and the mapping from findings to a disposition is four lines bounded by the legality matrix.

---

## 8. The dossier

The report is the product of this module. It has a fixed shape so you can learn to read it quickly
and notice when a section is thin.

Ordering is deliberate. **Open questions come second, before the step-by-step.** If escalations sat
at the bottom you would read forty pages of confident output first and arrive primed to approve.
And per SR4 the dossier must not open with cost or duration.

```
# Run <run_id> — <style> / <scene>
Mode: speculative · KB version: <sha> · Status: awaiting review

## 1. What we are proposing to publish
   Hero image, title, 13 tags, category, price, the description, the Etsy payload path.

## 2. Open questions — read these first
   Every escalation, with the step, the reason, what the two agents disagreed about,
   and what we need from you. Empty section stated explicitly as "none".

## 3. The research behind this style
   A0's demand-to-competition finding, sources with links, search calls made.
   ResearchQa's findings verbatim. If the style fragmented, that is stated here.

## 4. The style spec we are running against
   The nine axes, each with the step that set it, the rule cited, and whether it
   was resolved by borderline default.

## 5. Step by step
   For each of the 38: what ran, what it produced, the rule it derived from,
   the QA verdict, the disposition and who closed it. Rewinds shown in place,
   with what triggered them.

## 6. Why we think this will work
   Claims only, each citing a finding from §3-§5 or a rule file. No unsourced
   assertion is permitted in this section — it is generated from citations, not prose.

## 7. What we could not verify
   Every advisory finding accepted, every unresolvable citation, every budget
   that was hit, and the deferred items (conversion thresholds, image merit).

## 8. If you approve
   Exactly what the committed run will do: files written, git commit, Etsy call.
```

Section 6 is generated from `QaFinding` rows with `severity: pass` and resolved citations. It
cannot contain a claim that no finding supports. This is the section most likely to become
persuasive fluff, so it is built from data rather than written.

---

## 9. The human gate

One screen. Three actions.

```ruby
# app/controllers/dossier_reviews_controller.rb
class DossierReviewsController < ApplicationController
  def index
    @runs = PipelineRunRecord.where(status: "awaiting_dossier_review").order(dossier_ready_at: :desc)
  end

  def show
    @run = PipelineRunRecord.find_by!(run_id: params[:id])
  end

  def update
    @run = PipelineRunRecord.find_by!(run_id: params[:id])
    case params[:decision]
    when "approve"
      @run.update!(status: "approved", reviewed_at: Time.current,
                   reviewer_notes: params[:notes])
      CommitRunJob.perform_later(run_id: @run.run_id)
    when "rerun"
      step = params.require(:step_id)
      @run.update!(status: "rerunning", reviewer_notes: params[:notes])
      RerunFromStepJob.perform_later(run_id: @run.run_id, step_id: step,
                                     guidance: params[:notes])
    when "abandon"
      @run.update!(status: "abandoned", reviewed_at: Time.current,
                   reviewer_notes: params[:notes])
    end
    redirect_to dossier_reviews_path
  end
end
```

**Rerun** uses module 08's graph rather than inventing anything: `invalidates` clears the
downstream fields, and the conductor resumes from the named step with your note added to context.
Your guidance is carried as reviewer context, so a rerun of A1 with "too many product-only shots"
reaches the step that can act on it.

**Approve** is the only path to `CommitRunJob`, which is the only place `RunMode.with("committed",
…)` is called. It replays the writes: A5 and B7's spec files move from staging into
`knowledge_base/`, the git commit runs, then P3_8 calls Etsy. If any step fails during commit, the
run stops and nothing partial is published.

---

## 10. Rake tasks

```ruby
# lib/tasks/run.rake
namespace :run do
  desc "Speculative end-to-end run. Writes nothing outside tmp/. rake run:speculative style=x scene=y"
  task speculative: :environment do
    run = Agents::Conductor.run_speculative(style_slug: ENV.fetch("style"),
                                            scene_spec_id: ENV.fetch("scene"))
    puts "Run #{run.run_id} → #{run.status}"
    puts "Escalations: #{run.escalations.size}"
    puts "Dossier: bin/rails run:dossier id=#{run.run_id}"
  end

  desc "Print a run's dossier. rake run:dossier id=run_20260902_a3f1"
  task dossier: :environment do
    puts PipelineRunRecord.find_by!(run_id: ENV.fetch("id")).dossier_markdown
  end

  desc "Approve and commit a reviewed run. rake run:commit id=... "
  task commit: :environment do
    run = PipelineRunRecord.find_by!(run_id: ENV.fetch("id"))
    abort "Run is #{run.status}, expected awaiting_dossier_review." unless
      run.status == "awaiting_dossier_review"
    run.update!(status: "approved", reviewed_at: Time.current, reviewer_notes: ENV["notes"])
    CommitRunJob.perform_now(run_id: run.run_id)
    puts "Committed. Listing: #{run.reload.piece_record&.etsy_listing_id}"
  end

  desc "Rerun from a step with guidance. rake run:rerun id=... step=A1 notes='...'"
  task rerun: :environment do
    RerunFromStepJob.perform_now(run_id: ENV.fetch("id"), step_id: ENV.fetch("step"),
                                 guidance: ENV["notes"])
  end
end
```

---

## 11. `knowledge_base/rules/qa_rules.yml`

Thresholds the specialists read. Kept out of the agent classes so they are reviewable as a diff.

```yaml
meta:
  source: "Module 09 §5 — QA specialist thresholds"
  citation: >
    Where a threshold restates an existing rule it cites that rule and does not redefine it
    (a2 markers/images from mood.yml validation; tags from etsy_tags.yml). Where no source
    exists — image conformance axes, single-word tag tolerance — it is a project convention and
    is marked as such, following generation_constraints.yml's precedent.
  volatility: static

rules:
  research_qa:
    search_floor:
      restates: "module 00b Search::ReasonedRunner min_rounds; A0 = 4, A1 = 5"
      on_fail: blocking
    source_independence:
      min_sources_per_item: 2
      restates: "reference_set_criteria.yml image_requirements"
      on_fail: advisory

  axis_qa:
    a2:
      required_markers: 2
      required_images: 3
      restates: "mood.yml validation.rule — 3+ images across 2+ of the 4 markers"
      on_fail: blocking

  image_qa:
    scope: >
      Conformance only. This agent does not judge aesthetic merit, marketability, or whether one
      candidate is nicer than another. No document in the knowledge base defines image quality,
      so an agent scoring it would be inventing a standard. Merit is decided at C2_chosen, which
      is Tier 3.
    conformance_axes: [mood, content_type, color_role, frame_form]
    reference_comparison:
      enabled: true
      max_reference_images: 4
      reasoning: >
        A1's curated set is the only recorded statement of what this style looks like. Comparing
        candidates against it is checkable; comparing them against taste is not.
    on_no_conforming_candidate: blocking

  listing_qa:
    tags:
      required_slots: 13
      max_single_word: 3
      restates: "etsy_tags.yml slot_count and phrase_style"
      convention_note: "max_single_word is a project convention; Etsy states no such limit."
    title:
      min_first_six_chars: 20
      convention_note: "Project convention operationalising the 'first six words' guidance."
    policy:
      shipping_ratio_warn: 0.4
      restates: "etsy_policy.yml validation.warn_if — heuristic, warns rather than blocks"

  customer_safety_qa:
    watched_topics: [hanging_hardware, weight_ratings, conservation_glass, humidity_placement]
    on_untraceable_claim: blocking
    citation: "Phase 2 §6 Limitation 4 — customer-facing accuracy must be fact-checked"

  evidence_qa:
    unresolvable_citation: void_disposition_and_escalate
    citation: "decision_rules.yml SR11"
```

---

## 12. Verification

```bash
# 1. Speculative mode writes nothing outside tmp/
bin/rails runner '
  before = Dir[Rails.root.join("knowledge_base/**/*")].map { |f| [f, File.mtime(f)] }.to_h
  run = Agents::Conductor.run_speculative(style_slug: "japandi-v1", scene_spec_id: "behind_sofa_light_neutral")
  after = Dir[Rails.root.join("knowledge_base/**/*")].map { |f| [f, File.mtime(f)] }.to_h
  puts before == after ? "knowledge_base untouched: ok" : "FAIL: #{(after.to_a - before.to_a).inspect}"
  puts "staging exists: #{Dir.exist?(Rails.root.join("tmp/runs/#{run.run_id}/staging"))}"
'

# 2. Etsy publish refuses in speculative mode
bin/rails runner '
  Workflow::RunMode.with("speculative", run_id: "t1") do
    begin
      Workflow::RunMode.require_committed!("Etsy publish")
      puts "FAIL: allowed"
    rescue Workflow::SpeculativeWriteError
      puts "refuses Etsy publish speculatively: ok"
    end
  end
'

# 3. Default mode is speculative when nothing is in scope
bin/rails runner 'puts Workflow::RunMode.speculative? ? "defaults safe: ok" : "FAIL"'

# 4. No agent can close a Tier 3 gate
bin/rails runner '
  %w[A0 A5 B0 B7 C2_chosen P2_0 P2_7 P3_7].each do |s|
    begin
      Workflow::DecisionRules.validate_disposition!(
        step_id: s, verdict: "clean", disposition: "approve",
        reviewer_kind: "agent", payload: { citations: [{ "rule_path" => "mood.rules" }] })
      puts "FAIL: agent closed #{s}"
    rescue Workflow::DecisionRules::IllegalDisposition
      puts "#{s} refuses agent closure: ok"
    end
  end
'

# 5. An agent disposition without citations is refused
bin/rails runner '
  begin
    Workflow::DecisionRules.validate_disposition!(
      step_id: "P3_3", verdict: "clean", disposition: "approve",
      reviewer_kind: "agent", payload: { citations: [] })
    puts "FAIL: allowed uncited"
  rescue Workflow::DecisionRules::IllegalDisposition
    puts "refuses uncited agent disposition: ok"
  end
'

# 6. EvidenceQa catches a fabricated rule path
bin/rails runner '
  puts Agents::EvidenceQa.resolves?("mood.rules.scoring.mixed_result") ? "real path ok" : "FAIL"
  puts Agents::EvidenceQa.resolves?("mood.rules.totally.invented.key") ? "FAIL" : "fake path caught: ok"
'

# 7. AxisQa refuses to force a mixed A2 scorecard
bin/rails runner '
  run = PipelineRunRecord.create!(run_id: "t2", kb_version: "dirty:test")
  res = Steps::StepResult.new(status: :awaiting_human, data: { "result" => { "mood" => "mixed" } })
  f = Agents::AxisQa.call(run: run, step_id: "A2", result: res, context: {})
  puts f.any?(&:blocking?) ? "A2 mixed blocks: ok" : "FAIL"
  run.destroy!
'

# 8. Every gated step has a QA agent
bin/rails runner 'puts Agents::Registry.validate_coverage! ? "coverage: ok" : "FAIL"'

# 9. Tier 2 divergence escalates rather than tie-breaking
bin/rails runner '
  puts Agents::BlindVerifier.instance_methods(false).none? { |m| m.to_s.include?("tiebreak") } ?
    "no tiebreaker: ok" : "FAIL"
'

# 10. positioning.yml survives P3_6 own universal-claim check
bin/rails runner '
  t = KnowledgeBase::RuleSet.load("positioning").rules.dig("positioning", "positioning_target")
  puts t.downcase.match?(/\b(everyone|anyone|anybody)\b/) ? "FAIL" : "positioning is specific: ok"
'

# 11. Pre-piece gates are now recorded (module 08 G1)
bin/rails runner '
  puts HumanGate.column_names.include?("reviewer_kind") ? "reviewer_kind present: ok" : "FAIL"
  puts HumanGate.columns.find { |c| c.name == "piece_record_id" }.null ? "nullable: ok" : "FAIL"
'
```

**Also verify by hand:** run `run:speculative` end to end, read the dossier, and confirm §2 lists
every Tier 3 gate as an open question rather than a closed decision. Confirm §6 contains no claim
without a citation. Confirm the dossier does not open with a cost or duration figure (SR4). Then
`run:rerun` one step and confirm the invalidated downstream fields actually cleared.

---

## 13. What this module does and does not change

**Resolved from module 08's open gaps:** G1 (pre-piece gates now recorded — `piece_record_id`
nullable, early return removed), G4 (verdict-dependent closure enforced through the shared gate
closer), G5 (image QA scoped to conformance, with the absence of a merit rubric stated rather than
papered over).

**Still open:**

- **G2 — performance thresholds.** Deferred by decision. When live data exists, S9 lands in
  `decision_rules.yml` and a `PerformanceQa` joins the registry reading module 07's export.
- **Track B still needs its driver.** This module's conductor walks the registry, which covers
  B0–B7, so a full run works. But `pipeline:track_b_step`-style session carry-forward for driving
  Track B by hand does not exist. If you ever need to run Track B outside a conductor run, that
  gap from module 08 is still there.
- **`Context::Assembler` is specified, not written.** The conductor calls it to build each step's
  context from prior results. Module 01c's `TrackASequence::SOURCES` is the pattern and covers
  A_IDEATE–A5; the same table needs extending across B, C, P2 and P3. This is the single largest
  piece of implementation work in the module and is deliberately called out rather than buried.
- **Aesthetic merit has no automated proxy and should not acquire one** without a sourced rubric.
  C2 stage 2 stays Tier 3. If it ever moves, that is a knowledge-base change with a citation, not
  an agent improvement.
