# Module 01b — Track A Ideation (upstream of A0)

> **Self-contained addendum to module 01.** This adds ONE new step ahead of the existing A0–A5
> sequence. It does not modify A0's contract, schema, prompt, or step class in any way — Track A as
> already built keeps working exactly as it does today. Do not search the internet for the domain
> content; it's all here.

---

## Contract

**Depends on:** module 00 (`Steps::Base`, `config/step_registry.yml`), module 00b
(`Search::ReasonedRunner` — this step reuses it, no new search infrastructure), module 01 (A0's
existing contract, which this step feeds but does not alter).

**Provides:**
- `knowledge_base/rules/ideation_constraints.yml` — candidate count cap, source-diversity
  requirement, promotional-language flagging
- `knowledge_base/prompts/a_ideate_style_candidates.md`
- `app/steps/track_a/ideate_style_candidates.rb` — the new step class
- `app/llm/schemas/track_a/style_ideation_schema.rb`
- One new entry in `config/step_registry.yml` (an addition, not a rewrite of the existing file)
- One new rake task in `lib/tasks/pipeline.rake` (an addition to the existing file)

**Consumed by:** you, manually — you read the candidates, pick one, and feed its name into the
existing `pipeline:track_a` command exactly as before. This step does not auto-chain into A0; the
human choice in between is the point.

**Must not:** touch A0's `context` shape, prompt, schema, or validation logic. Must not itself
render a demand/competition verdict rigorous enough to skip A0 — this step is deliberately shallow;
A0 remains the only step that validates a single named style in depth.

---

## 1. Why this is a separate step, not a wider A0

A0 and this step have different jobs and need different search budgets:

- **A0** — deep, narrow: one named style, many independent shops, cross-checked against Google
  Trends, competition ratio computed, promotional sources flagged. Expensive and rigorous on
  purpose.
- **This step** — shallow, wide: no named style yet, survey broadly across trend sources, surface
  N candidates each with a one-line signal. Cheap and approximate on purpose.

Combining them into one call means either the survey is too shallow to trust, or the per-candidate
validation is too broad to be rigorous — you'd get worse versions of both. Keeping them separate
also means this addition touches nothing already working: A0's contract (`context: { style_name:,
style_slug: }`) is unchanged, so any `HumanGate` rows, rake tasks, or registry entries already
built around A0 keep working exactly as they are.

This mirrors what actually happened historically in this project: a broad trend survey in one
session, followed by rigorous single-style validation in another, done separately and at different
times. This step formalizes that split instead of relying on you doing the broad pass manually in
chat each time.

### 1.1 Grounding for the candidate cap

Same reasoning as Track C's batch cap (module 03 §1.3): *The Paradox of Choice* — more options
doesn't produce a better decision, especially when you still have to pick one to hand to A0. The
cap keeps this step from dumping 20 vague possibilities on you.

---

## 2. Rule file

### 2.1 `knowledge_base/rules/ideation_constraints.yml`

```yaml
meta:
  source: "Module 01b — style ideation, upstream of Track A Step A0"
  citation: >
    Project precedent, not a book or platform rule. Derived from this project's own history:
    an Aug 17 2026 research session flagged vendor-authored trend blogs (print-on-demand
    vendors promoting their own tooling) as promotional framing rather than neutral evidence,
    after a naive Etsy "best-selling" survey was shown to conflate genuine demand with
    shop-level marketing strength and inflated variant counts. This file formalizes that
    correction as a standing rule.
  volatility: static
  note: >
    Distinct from A1's citation (module 01 §2.1) in the same way: not book-grounded, but
    held to its own explicit discipline rather than left as an unconstrained survey.

rules:
  candidate_count:
    default: 5
    max: 8
    reasoning: >
      Paradox of Choice grounding (module 03 §1.3 uses the same principle for the art-batch
      cap) — more candidates doesn't produce a better pick, it produces more time spent
      comparing options that were never going to be chosen.

  source_diversity:
    min_independent_sources_per_candidate: 2
    reasoning: >
      Same bar as A1's reference-set requirement (module 01 §2.1) — a candidate surfaced by
      only one source (one blog, one shop) is not yet a real signal, just one source's opinion.

  promotional_language_indicators:
    # Soft-flag pattern list, same design as module 07's anti-regression soft flags
    # (knowledge_base/rules/anti_regressions.yml) — surfaced as a warning, not a hard block.
    phrases:
      - "get there early"
      - "sellers who"
      - "join now"
      - "exclusive offer"
      - "coupon"
      - "act now"
      - "don't miss"
    rule: >
      If a source's own language matches these patterns, flag it as promotional framing in
      the candidate's signal notes rather than reporting its trend claim as neutral fact.
      This does not exclude the source — a promotional blog can still be directionally
      correct — it just means the claim should be corroborated elsewhere before being
      trusted, per source_diversity above.

  explicit_non_validation_notice:
    rule: >
      This step's output is NOT a validation verdict. Every candidate still requires a full
      A0 run before any production commitment. This step exists to generate candidates
      worth spending an A0 call on — nothing here should be read as "this style is proven."
```

---

## 3. Prompt file

### 3.1 `knowledge_base/prompts/a_ideate_style_candidates.md`

```markdown
Survey current wall-art / home-decor style trends broadly and surface %{candidate_count}
candidate styles worth considering for a wall-hanging print business.

%{direction_clause}

This is a SHALLOW, WIDE survey — not a deep validation of any one style. Do not attempt to
compute a rigorous demand-to-competition ratio for each candidate; that level of scrutiny is a
separate, later step (Step A0) applied to whichever ONE candidate gets chosen from this list.

For each candidate, report:

1. **A specific, nameable style** — not a vague mood word. "Warm minimalist textured abstract"
   is a candidate; "cozy vibes" is not.
2. **A one-line trend signal** — what specifically suggests this is resonating right now
   (a named trend report, a retailer's own style guide, a recurring pattern across independent
   shop listings).
3. **How many genuinely independent sources** support this candidate — retailer guides, trend
   blogs, and direct marketplace listings count as separate sources; two mentions on the same
   blog do not count as two sources.
4. **Whether any source's own language reads as promotional** — phrases like "get there early,"
   "sellers who...," "join now," "exclusive offer," "coupon," "act now," "don't miss." Flag this
   per-source, don't exclude the source, just don't treat its trend claim as neutral if the
   framing is selling something.
5. **A rough competition read** — low / medium / high / unknown. This is a first impression from
   what you find during the survey, not a computed ratio.

Do not surface a candidate you can only support from a single source. Stop at
%{candidate_count} candidates even if you find more — this list is meant to be short enough to
actually choose from, not exhaustive.

Return JSON matching the required schema.
```

---

## 4. Schema

```ruby
# app/llm/schemas/track_a/style_ideation_schema.rb
module Schemas
  module TrackA
    class StyleIdeationSchema < RubyLLM::Schema
      array :candidates do
        object do
          string :name, description: "A specific, nameable style — not a vague mood word"
          string :trend_signal, description: "One-line explanation of why this is surfacing now"
          integer :independent_source_count,
                  description: "How many genuinely independent sources support this candidate. Must be >= 2 to be included."
          array :sources do
            object do
              string :source_name
              boolean :promotional_language_detected
            end
          end
          string :competition_read, enum: %w[low medium high unknown]
        end
      end
      string :survey_notes,
             description: "Anything about the survey itself worth flagging — sparse data, conflicting signals, etc."
    end
  end
end
```

---

## 5. Step class

```ruby
# app/steps/track_a/ideate_style_candidates.rb
module Steps
  module TrackA
    class IdeateStyleCandidates < Steps::Base
      step id: "A_IDEATE",
           mechanism: :llm_text,
           ownership: "[AGENT-READY for the research — human picks which candidate to validate]"

      # context: { direction: (optional String — a loose steer, e.g. "something calm and neutral"),
      #            candidate_count: (optional Integer) }
      def perform
        constraints = rules("ideation_constraints").rules
        count = [context.fetch(:candidate_count, constraints["candidate_count"]["default"]).to_i,
                 constraints["candidate_count"]["max"]].min

        direction_clause = if context[:direction].present?
                             "Steer toward this rough direction if it fits current trends: " \
                             "#{context[:direction]}. Don't force it if nothing trending matches."
                           else
                             "No specific direction requested — survey broadly across current " \
                             "home-decor and wall-art trends."
                           end

        result = Search::ReasonedRunner.call(
          model: Pipeline::TEXT_MODEL,
          schema: Schemas::TrackA::StyleIdeationSchema,
          task: "You are surveying current wall-art style trends to surface candidates for a " \
                "print business — a broad, shallow pass, not a deep validation of any one style.",
          question: prompt("a_ideate_style_candidates",
                           candidate_count: count, direction_clause: direction_clause),
          max_rounds: 10   # broader survey than A0's single-style deep dive, so a larger budget
        )

        candidates = result[:content]["candidates"] || []
        min_sources = constraints["source_diversity"]["min_independent_sources_per_candidate"]
        weak = candidates.select { |c| c["independent_source_count"].to_i < min_sources }

        needs_human(
          "#{candidates.size} candidate(s) surveyed (#{result[:search_calls_made]} live searches). " \
          "#{weak.any? ? "#{weak.size} candidate(s) below the #{min_sources}-source minimum — " \
                          "weaker signal, shown for completeness." : 'All candidates meet the ' \
                          "source-diversity bar."} " \
          "Pick ONE and run it through the existing Track A pipeline: " \
          "`bin/rails pipeline:track_a style_slug=<slug> style_name=\"<chosen name>\"`. " \
          "This step is NOT validation — A0 still runs in full against whichever you pick.",
          { candidates: candidates, weak_candidates: weak.map { |c| c["name"] },
            survey_notes: result[:content]["survey_notes"] }
        )
      rescue Search::NoSearchPerformedError => e
        fail_step("Ideation could not complete: #{e.message}", {})
      end
    end
  end
end
```

**Note this always returns `needs_human`, never `ok`.** There's no "auto-approve" path — picking
which candidate to pursue is inherently a human choice, so unlike some other `[AGENT-READY]` steps
in this pipeline, this one has no straight-through case.

---

## 6. Wiring into the already-running app

The codebase already exists and A0–A5 already run. This step is an **addition**, not a rebuild —
apply these as targeted edits, not replacements.

### 6.1 Add to `config/step_registry.yml`

Insert a new entry into the existing `phase_1.track_a.steps` array, **before** the `A0` entry.
Do not renumber or touch any existing entry.

```yaml
      - id: A_IDEATE
        title: "Survey style candidates"
        ownership: "[AGENT-READY for the research — human picks which candidate to validate]"
        mechanism: llm_text
        human_gate: true
        klass: "Steps::TrackA::IdeateStyleCandidates"
```

### 6.2 Add to `lib/tasks/pipeline.rake`

Add a new task alongside the existing `track_a` task — do not modify `track_a` itself.

```ruby
  desc "Survey style candidates before committing to one. Usage: rake pipeline:ideate_styles [direction='calm and neutral'] [count=5]"
  task ideate_styles: :environment do
    context = {}
    context[:direction] = ENV["direction"] if ENV["direction"].present?
    context[:candidate_count] = ENV["count"].to_i if ENV["count"].present?

    result = Workflow::StepDispatcher.call(step_id: "A_IDEATE", piece: nil, context: context)
    puts result.message
    puts JSON.pretty_generate(result.data[:candidates])
  end
```

### 6.3 Nothing else changes

`A0` through `A5`'s classes, prompts, schemas, and the existing `pipeline:track_a` task are
untouched. The only new call site is the new rake task above.

---

## 7. How this fits into the Track A run order

```
[NEW] A_IDEATE (survey — human reads candidates, picks ONE)
   ↓
   You run: bin/rails pipeline:track_a style_slug=<slug> style_name="<chosen name>"
   ↓
A0 (deep validation of the ONE chosen candidate — unchanged from module 01)
   ↓
A1 → A2 → A3 → A4 → A5 (unchanged from module 01)
```

`A_IDEATE` is optional per run — if you already know what style you want (as in your first style),
you can skip straight to `pipeline:track_a` exactly as before. It exists for the case you were
actually in: no idea where to start.

---

## 8. Verification for this module

```bash
# 1. Rule file exists, carries citation, cap values correct
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("ideation_constraints").rules
  puts "default=#{r["candidate_count"]["default"]}"    # expect 5
  puts "max=#{r["candidate_count"]["max"]}"             # expect 8
  puts "min_sources=#{r["source_diversity"]["min_independent_sources_per_candidate"]}"  # expect 2
  puts "promo_phrases=#{r["promotional_language_indicators"]["phrases"].size}"  # expect 7
'

# 2. Prompt renders with both a direction and no-direction case
bin/rails runner '
  t = Pipeline::KB_ROOT.join("prompts/a_ideate_style_candidates.md").read
  puts format(t, candidate_count: 5, direction_clause: "Steer toward calm and neutral.").size
  puts format(t, candidate_count: 5, direction_clause: "No specific direction requested.").size
'

# 3. New step class matches its own registry entry (added, not conflicting with A0-A5)
bin/rails runner '
  reg = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  steps = reg["phase_1"]["track_a"]["steps"]
  ideate = steps.find { |s| s["id"] == "A_IDEATE" }
  raise "A_IDEATE missing from registry" unless ideate
  k = ideate["klass"].constantize
  puts "id match: #{k.step_id == "A_IDEATE"}"
  puts "ownership match: #{k.ownership == ideate["ownership"]}"
  # Confirm A0-A5 still present and untouched
  puts "A0-A5 still present: #{%w[A0 A1 A2 A3 A4 A5].all? { |id| steps.any? { |s| s["id"] == id } }}"
  puts "total track_a steps now: #{steps.size}"    # expect 7 (was 6)
'

# 4. Step always returns awaiting_human, never ok — no auto-approve path
bin/rails runner '
  src = File.read(Rails.root.join("app/steps/track_a/ideate_style_candidates.rb"))
  puts src.include?("needs_human") ? "has needs_human: ok" : "MISSING needs_human"
  puts src.match?(/\bok\(/) ? "WARNING: has an ok() path — should not" : "no ok() path: correct"
'

# 5. Weak-candidate filter works
bin/rails runner '
  weak_check = ->(candidates, min) { candidates.select { |c| c["independent_source_count"].to_i < min } }
  sample = [{"name" => "A", "independent_source_count" => 1}, {"name" => "B", "independent_source_count" => 3}]
  weak = weak_check.call(sample, 2)
  puts "weak count: #{weak.size}"    # expect 1
  puts "weak name: #{weak.first["name"]}"    # expect A
'

# 6. A0 is completely unmodified — same ownership tag, same context shape
bin/rails runner '
  puts Steps::TrackA::ValidateStyle.ownership
  # expect exactly: [AGENT-READY for the research — human confirms the go/no-go]
  src = File.read(Rails.root.join("app/steps/track_a/validate_style.rb"))
  puts src.include?("context.fetch(:style_name)") ? "A0 context shape unchanged: ok" : "A0 CHANGED — investigate"
'

# 7. Rake task registered
bin/rails -T pipeline 2>/dev/null | grep -c "ideate_styles"    # expect 1
```

**Also verify by hand:**
- Run `bin/rails pipeline:ideate_styles` with no arguments and confirm it produces 5 candidates
  (the default), each with a trend signal, source count, and competition read.
- Run it again with `direction='bold and colorful'` and confirm the steer actually shows up in
  the results, without forcing an unrelated candidate to fit.
- Confirm `bin/rails pipeline:track_a` still works exactly as it did before this addendum, taking
  a style_slug/style_name pair with no awareness that `A_IDEATE` exists.

---

## 9. Coverage note

This module isn't part of the original three-phase source docs — it's a capability gap identified
in conversation, not an extraction from `how_to_arrange_pictures` / the business books / the Etsy
handbook. Its only "source" is this project's own precedent (the Aug 17 research session that
first surfaced and fixed the best-seller-signal problem), captured in `meta.citation` above rather
than a book or platform citation. Nothing in `00-EXTRACTION-MANIFEST.md` maps to this file, and
that's expected — it's a new addition to the system, not a corrected extraction from the original
three docs.
