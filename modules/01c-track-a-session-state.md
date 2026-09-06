# Module 01c — Track A Session State (carry-forward between steps)

> **Self-contained addendum.** Adds one orchestration layer on top of Track A. Does not modify
> A0–A5's step classes, prompts, or schemas in any way — everything patched in module 01's update
> and everything in module 01b keeps working exactly as it does today.

---

## Contract

**Depends on:** module 00 (`Workflow::StepDispatcher`, `config/step_registry.yml`), module 01
(A0–A5, unmodified), module 00b's/01's A0 patch (this is what makes `single_recommended_focus`
worth carrying forward in the first place), module 01b (`A_IDEATE`, if used, also feeds the
session).

**Provides:**
- `app/services/workflow/track_a_session.rb` — reads/writes one JSON file per style-in-progress
- `app/services/workflow/track_a_sequence.rb` — the step order + which fields each step needs and
  where they come from (session or fresh human input)
- One new rake task, `pipeline:track_a_step`, replacing the pattern of manually re-typing
  `style_name` (and later `mood`, `content_type`, etc.) at every single invocation

**Consumed by:** you, running Track A. The existing `pipeline:track_a` task (module 01) and the
per-track-B/track-C tasks are untouched — this only changes how Track A is *driven*, not what it
does.

**Must not:** modify `app/steps/track_a/*.rb`. The whole point is that carrying values forward is
an orchestration concern, not something the step classes need to know about.

---

## 1. Why this is a pure wrapper, not a change to the steps themselves

The tempting fix is to make each A-step read its own defaults from a shared file. Don't do that —
it means touching five already-correct, already-verified step classes to add file I/O they don't
conceptually need. Instead, keep every step class exactly as it is (it just takes `context`, same
as always) and put the carry-forward logic in the thing that calls them.

This mirrors how the daily pipeline already works: `Steps::Base` classes know nothing about
`PieceRecord` chaining — that's `Workflow::PipelineRun`'s job (module 06 §6). Track A never had an
equivalent because it runs pre-piece and was originally driven by hand, one rake task at a time.
This module is that missing equivalent, scoped to Track A only.

### 1.1 What's genuinely fresh input vs. what should carry forward

Not everything can be defaulted — some steps are new judgment calls every time, not values already
decided. The dividing line:

| Step | What carries forward from session | What must be fresh input each call |
|---|---|---|
| A_IDEATE | — | `direction` (optional), `candidate_count` (optional) |
| A0 | `style_name` (from your chosen A_IDEATE candidate, if used) | `style_name` if not using A_IDEATE; your go/no-go |
| A1 | `style_name` | Which candidate images to keep/drop (your curation) |
| A2 | `style_name`, curated `reference_images` | — (single-call step; its own output is final) |
| A3 | `reference_images` | — |
| A4 | `reference_images`, `mood` (from A2) | — |
| A5 | `style_slug`, `style_name`, `mood`, `content_type`, `frame_form` | `confirmed: true` — never defaulted |

**A5's `confirmed` is deliberately never auto-filled.** That's the actual lock action — module 01
§6.6 built it that way on purpose (`unless context[:confirmed]`), and auto-supplying it would
silently remove the one real gate in the whole track. Everything else on that row is exactly the
kind of already-decided value this module exists to stop you retyping.

---

## 2. `Workflow::TrackASession`

One JSON file per style-in-progress, under `tmp/` — deliberately **not** `knowledge_base/`. This is
scratch state for an in-progress decision, not a locked artifact; the only thing that ever lands in
`knowledge_base/` is A5's final write via `StyleSpecWriter`, unchanged from module 01.

```ruby
# app/services/workflow/track_a_session.rb
module Workflow
  class TrackASession
    ROOT = Rails.root.join("tmp", "track_a_sessions")

    def self.path_for(style_slug) = ROOT.join("#{style_slug}.json")

    def self.load(style_slug)
      path = path_for(style_slug)
      return { "style_slug" => style_slug, "decisions" => {}, "last_completed_step" => nil } unless path.exist?

      JSON.parse(path.read)
    end

    def self.save!(style_slug, session)
      ROOT.mkpath
      path_for(style_slug).write(JSON.pretty_generate(session))
    end

    # Called after every step that returns :ok or :awaiting_human — failed steps don't get
    # recorded, so a bad run doesn't poison the next attempt's defaults.
    def self.record_step_result!(style_slug, step_id, result_data)
      session = load(style_slug)
      session["decisions"][step_id] = result_data
      session["last_completed_step"] = step_id
      save!(style_slug, session)
    end

    def self.reset!(style_slug)
      path = path_for(style_slug)
      path.delete if path.exist?
    end
  end
end
```

---

## 3. `Workflow::TrackASequence` — the field-mapping table, as code

This is where §1.1's table becomes executable. Each step declares which session-stored values it
needs and under which key they were stored.

```ruby
# app/services/workflow/track_a_sequence.rb
module Workflow
  class TrackASequence
    ORDER = %w[A_IDEATE A0 A1 A2 A3 A4 A5].freeze

    # For each step, where its context values come from:
    #   { key => [:session, "STEP_ID", "field_in_that_step's_result_data"] }  — auto-filled
    #   { key => :fresh }                                                     — must be passed this call
    SOURCES = {
      "A_IDEATE" => {},   # everything optional/fresh — see step class
      "A0" => {
        style_name: :fresh,      # first call in a session — nothing to carry forward from yet
        style_slug: :fresh
      },
      "A1" => {
        style_name: [:session, "A0", "style_name_used"]   # see §3.1 note below
      },
      "A2" => {
        reference_images: [:session, "A1", "curated_images"]
      },
      "A3" => {
        reference_images: [:session, "A2", "reference_images"]
      },
      "A4" => {
        reference_images: [:session, "A3", "reference_images"],
        mood: [:session, "A2", "mood"]
      },
      "A5" => {
        style_slug: :fresh,   # session key itself, always explicit for safety
        style_name: [:session, "A0", "style_name_used"],
        mood: [:session, "A2", "mood"],
        content_type: [:session, "A3", "content_type"],
        frame_form: [:session, "A4", "frame_form"],
        confirmed: :fresh     # NEVER auto-filled — see §1.1
      }
    }.freeze

    def self.next_step_for(session)
      last = session["last_completed_step"]
      return ORDER.first if last.nil?

      idx = ORDER.index(last)
      raise ArgumentError, "Unknown last_completed_step=#{last}" if idx.nil?
      ORDER[idx + 1]
    end

    # Merges session-derived defaults with fresh_context (fresh_context always wins on conflict —
    # an explicit override this call beats whatever the session remembers).
    def self.build_context(step_id, session, fresh_context)
      mapping = SOURCES.fetch(step_id, {})
      derived = mapping.each_with_object({}) do |(key, source), ctx|
        next if source == :fresh   # caller must supply this; skip auto-fill
        _, from_step, field = source
        value = session.dig("decisions", from_step, field.to_s)
        ctx[key] = value unless value.nil?
      end
      derived.merge(fresh_context)
    end

    # Which keys THIS call still needs that neither the session nor fresh_context supplied —
    # used to give a clear error instead of the step class failing on a missing context key.
    def self.missing_required(step_id, built_context)
      mapping = SOURCES.fetch(step_id, {})
      mapping.keys.select { |k| built_context[k].nil? }
    end
  end
end
```

### 3.1 Note on `style_name_used` vs. the original input

A0's result data (module 01 §6.1, post-patch) contains `findings["single_recommended_focus"]` —
the agent's narrowed pick — not a top-level `style_name_used` field. Before wiring this up, add one
small thing to A0's `perform` (the only step-class touch this module needs, and it's additive, not
a rewrite): after building `content`, include the value actually meant to carry forward:

```ruby
# One line added to Steps::TrackA::ValidateStyle#perform, in the ok/needs_human data hash:
{ findings: content, search_calls_made: result[:search_calls_made], brief: brief,
  style_name_used: content["breadth_assessment"] == "fragments_into_substyles" ?
                     content["single_recommended_focus"] : context.fetch(:style_name) }
```

This is the one-line reason A0 needs a small touch here — not to change its behavior, only to name
which of its two possible outputs (the original broad name, or the narrowed pick) is the one later
steps should treat as *the* style name going forward. Everything else about A0 is unchanged.

---

## 4. The rake task

Replaces retyping `style_name` (and eventually `mood`, `content_type`, `frame_form`) at every
Track A invocation.

```ruby
# lib/tasks/pipeline.rake — addition, does not replace the existing track_a task
namespace :pipeline do
  desc "Run the next (or a specified) Track A step, auto-filling context already decided this " \
       "session. Usage: rake pipeline:track_a_step style_slug=japandi-v1 " \
       "[step=A2] [confirmed=true] [context='{\"mood\":\"calm_ordered\"}']"
  task track_a_step: :environment do
    slug = ENV.fetch("style_slug")
    session = Workflow::TrackASession.load(slug)

    step_id = ENV["step"] || Workflow::TrackASequence.next_step_for(session)

    fresh = ENV["context"] ? JSON.parse(ENV["context"]).symbolize_keys : {}
    fresh[:confirmed] = true if ENV["confirmed"] == "true"

    context = Workflow::TrackASequence.build_context(step_id, session, fresh)
    missing = Workflow::TrackASequence.missing_required(step_id, context)

    if missing.any?
      abort "#{step_id} needs #{missing.join(', ')} — pass via context='{...}' " \
            "(nothing in the session yet supplies #{missing.join(', ')} for this step)."
    end

    result = Workflow::StepDispatcher.call(step_id: step_id, piece: nil, context: context)

    Workflow::TrackASession.record_step_result!(slug, step_id, result.data) unless result.failed?

    puts "#{step_id} -> #{result.status}"
    puts result.message
    puts JSON.pretty_generate(result.data)
    puts
    puts result.awaiting_human? ?
           "Re-run with confirmed=true (and any edits via context=) to proceed, or move to the " \
           "next step by re-running this task with no `step=` argument." :
           "Next: rake pipeline:track_a_step style_slug=#{slug}"
  end

  desc "Reset a Track A session (does not touch any already-locked style_specs file)."
  task track_a_reset: :environment do
    Workflow::TrackASession.reset!(ENV.fetch("style_slug"))
    puts "Session cleared for #{ENV.fetch('style_slug')}."
  end
end
```

---

## 5. What using it actually looks like

Compare to the fully-manual version from earlier in this conversation.

```bash
$ bin/rails pipeline:track_a_step style_slug=japandi-v1 context='{"style_name":"Japandi"}'
A0 -> awaiting_human
⚠ Japandi FRAGMENTED into 7 distinct sub-themes... agent's pick: "Ensō / red-sun + mountain ink-style print"
...
Next: rake pipeline:track_a_step style_slug=japandi-v1

# You read the findings, decide the pick is right, approve:
$ bin/rails pipeline:track_a_step style_slug=japandi-v1 confirmed=true
A1 -> awaiting_human
# Notice: no style_name passed. It came from A0's recorded style_name_used automatically.
...

$ bin/rails pipeline:track_a_step style_slug=japandi-v1 context='{"curated_images": [...]}'
A2 -> awaiting_human
# reference_images was auto-filled from A1's curated set — you only supplied the curation edit.
...

$ bin/rails pipeline:track_a_step style_slug=japandi-v1
A3 -> awaiting_human
# No arguments at all needed — everything A3 needs already came from A1/A2.

$ bin/rails pipeline:track_a_step style_slug=japandi-v1
A4 -> awaiting_human
# mood auto-filled from A2. reference_images auto-filled from A3.

$ bin/rails pipeline:track_a_step style_slug=japandi-v1 confirmed=true
A5 -> ok
# mood, content_type, frame_form all auto-filled from A2/A3/A4. Only the lock confirmation
# was fresh input. Writes knowledge_base/style_specs/japandi-v1.yml.
```

Five of the seven calls need zero or minimal fresh input. The two that do need it (A1's curation,
A5's explicit lock) are the two genuine judgment calls per §1.1 — not values the system could have
known on its own.

---

## 6. Verification for this module

```bash
# 1. Session round-trips
bin/rails runner '
  Workflow::TrackASession.reset!("test-style")
  s = Workflow::TrackASession.load("test-style")
  puts "fresh session: #{s["decisions"] == {}}"
  Workflow::TrackASession.record_step_result!("test-style", "A0", {"style_name_used" => "Test Style"})
  s2 = Workflow::TrackASession.load("test-style")
  puts "recorded: #{s2["decisions"]["A0"]["style_name_used"]}"    # expect "Test Style"
  puts "last_step: #{s2["last_completed_step"]}"                  # expect A0
  Workflow::TrackASession.reset!("test-style")
'

# 2. next_step_for walks the sequence correctly
bin/rails runner '
  puts Workflow::TrackASequence.next_step_for({"last_completed_step" => nil})     # expect A_IDEATE
  puts Workflow::TrackASequence.next_step_for({"last_completed_step" => "A0"})    # expect A1
  puts Workflow::TrackASequence.next_step_for({"last_completed_step" => "A4"})    # expect A5
'

# 3. build_context auto-fills from session and lets fresh_context override
bin/rails runner '
  session = {"decisions" => {"A0" => {"style_name_used" => "Ensō Ink"}}}
  ctx = Workflow::TrackASequence.build_context("A1", session, {})
  puts ctx[:style_name]    # expect "Ensō Ink"

  ctx2 = Workflow::TrackASequence.build_context("A1", session, {style_name: "Override Name"})
  puts ctx2[:style_name]   # expect "Override Name" — fresh always wins
'

# 4. missing_required flags what nothing has supplied yet
bin/rails runner '
  m = Workflow::TrackASequence.missing_required("A0", {})
  puts m.sort.inspect   # expect ["style_name", "style_slug"] — both :fresh, neither supplied
'

# 5. A5's confirmed is NEVER auto-filled, even if session somehow has a truthy value under that key
bin/rails runner '
  session = {"decisions" => {"A4" => {"confirmed" => true}}}   # contrived — A4 does not actually store this
  ctx = Workflow::TrackASequence.build_context("A5", session, {})
  puts ctx.key?(:confirmed) ? "FAIL — confirmed was auto-filled" : "confirmed correctly absent: ok"
'

# 6. Rake tasks registered
bin/rails -T pipeline 2>/dev/null | grep -c "track_a_step\|track_a_reset"   # expect 2
```

**Also verify by hand:**
- Run the full 7-call sequence from §5 against a real (or test) style and confirm the only two
  places you type a value are A1's curation and A5's `confirmed=true`.
- Confirm `A0`'s one-line addition (§3.1) doesn't change its `needs_human` message or ownership tag
  — only adds the `style_name_used` key to its returned data.
- Confirm `pipeline:track_a_reset` does not touch or delete anything under `knowledge_base/` — it
  only clears the scratch session file.

---

## 7. Coverage note

Like module 01b, this isn't an extraction from the three source docs — it's orchestration
infrastructure prompted by an actual gap surfaced in this conversation (you noticing that A0's
fixed output still had to be manually retyped into A1). Nothing in `00-EXTRACTION-MANIFEST.md`
maps to this file, and that's expected.
