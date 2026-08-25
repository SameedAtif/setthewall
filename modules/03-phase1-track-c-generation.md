# Module 03 — Phase 1, Track C: Art Generation

> **Self-contained.** The prompt-template rules and generation constraints are written out below
> verbatim. The image-generation provider is deliberately kept behind an adapter interface so it can
> be swapped without changing pipeline code — see §1.2.

---

## Contract

**Depends on:** module 00 (base infrastructure, `PieceRecord`, `Steps::Base`), module 01 (the style
spec must have `style_level` locked), module 02 (the scene spec must have `axes` locked for the
scene template being generated for).

**Provides:**
- `knowledge_base/rules/generation_prompt_template.yml` — the prompt-construction rules
- `knowledge_base/rules/generation_constraints.yml` — daily batch cap and finalist cull count
- `knowledge_base/prompts/c1_generation_prompt_synthesis.md` — the meta-prompt used to build each
  day's image-generation prompt from the style + scene spec
- `app/steps/track_c/generate_art.rb` (C1) — batch generation
- `app/steps/track_c/cull_to_finalists.rb` (C2) — human final pick
- `app/llm/schemas/track_c/prompt_synthesis_schema.rb`
- `app/services/image_generation/adapter.rb` — the provider-agnostic interface
- `app/services/image_generation/replicate_adapter.rb` — reference implementation using Flux
- `app/services/image_generation/manual_adapter.rb` — a no-API fallback for local testing without
  spending money

**Consumed by:** module 04 (Phase 2 reads `PieceRecord.chosen_url` — the finalist selected in C2).

**Must not:** call the image generation API for anything other than a real production run (a stray
call in a test suite is real money and, over time, real money you'd forget you spent), touch style
or scene axis values, publish anything to Etsy (that's module 05).

---

## 1. Track C's shape and the two things that make it different from A/B

### 1.1 It's the first daily-cadence step in the pipeline

Track A ran per-style. Track B ran per-scene-template. Track C runs **every day, one piece per scene
template you have configured** (typically 3). Every subsequent phase — 04 placement, 05 listing —
also runs daily against the piece C produces. This is where a real `PieceRecord` first exists.

### 1.2 The provider question

Image-generation providers churn faster than any other API in this stack. The plan builds Track C
around a small adapter interface (§4.1) with three concrete implementations:

- **`ManualAdapter`** — no API calls; prints a prompt to stdout and pauses for you to paste back a
  path to a manually-produced image. Zero cost. Use this while developing every other module. **Set
  as the default in `.env.example`.**
- **`ReplicateAdapter`** — calls Replicate's API to run Flux 1.1 Pro or Flux Schnell. Replicate hosts
  the open-weight Flux models at materially lower per-image cost than the model creators' own APIs,
  which matters for a daily-run workload. This is the recommended production default.
- **A third adapter you write later** if you want to try Midjourney, DALL-E, Ideogram, or a
  different Flux host. The interface (§4.1) is deliberately three methods — `generate`,
  `estimated_cost_usd`, `name` — nothing else. Adding a provider is under 50 lines.

Provider selected via `IMAGE_GEN_PROVIDER` in `.env`, chosen once at boot. Do not mix providers in
one run — the composite comparison in C2 and the performance analysis in module 07 both assume every
piece in a batch was generated the same way.

### 1.3 Grounding note on the batch cap

C1's daily batch cap and C2's cull rule aren't from the arrangement book — those books are about
placement, not production volume. They're from the business books:

- *The Paradox of Choice* — Ch. 5 "When Only the Best Will Do" and Ch. 6 "Why We Suffer": the
  maximizer trap says more options do not produce better decisions; they produce worse ones with
  more regret. A cap of ~10 candidates per scene is a satisficer discipline.
- *This Is Marketing* — Ch. 12 "Trust and Tension Create Forward Motion": the culled finalist is a
  commitment, not a tentative "we'll see if it sells" — the discipline of picking one enforces the
  posture.

These citations go in the rule files' `meta.citation` fields.

---

## 2. Rule files to create

### 2.1 `knowledge_base/rules/generation_constraints.yml`

```yaml
meta:
  source: "Phase 1, Steps C1 & C2 — Generate art / Cull to finalists"
  citation: >
    Grounding for the batch cap and cull rule: *The Paradox of Choice*, Ch. 5 "When Only the
    Best Will Do" and Ch. 6 "Why We Suffer" (the maximizer trap); *This Is Marketing*, Ch. 12
    "Trust and Tension Create Forward Motion" (the finalist is a commitment). The specific
    numbers below are working conventions in this project's C1/C2 source doc, not values the
    books prescribe — they operationalise the principle for this pipeline.
  volatility: static

rules:
  batch:
    max_candidates_per_scene: 10
    reasoning: >
      Cap on generation output per scene per day. Higher numbers do not produce better
      finalists — they produce longer culls and more regret. Enforced in code because a
      generation loop with no upper bound is a real risk (API cost and an unbounded cull
      queue).

  finalist_cull:
    max_finalists_per_scene: 3
    reasoning: >
      From C2's cull rule — narrow to a small set the human can compare side by side. Three
      is the working number; four is acceptable when the batch is very strong.
    absolute_max: 4

  chosen:
    count: 1
    reasoning: >
      C2 ends with ONE chosen piece per scene per day. This becomes PieceRecord.chosen_url
      and flows into Phase 2.
```

### 2.2 `knowledge_base/rules/generation_prompt_template.yml`

The rules that turn a style + scene spec into an image-generation prompt. Everything here comes
from axis values already determined by Track A and Track B — Track C does not introduce new axis
choices. This makes the prompt reproducible: same spec + same day = same prompt.

```yaml
meta:
  source: "Phase 1, Step C1 — Generate art"
  citation: >
    Content Type, Frame Form, Mood, and Color Role feed the prompt from the arrangement book's
    §2.1 (frame material by content type, p. 16-19), §2.2 (frame contour by content type, p. 19)
    and §2.7a (mood-driven arrangement modifier, p. 68-69). Space tips modifier from p. 51.
    Track C composes these; module 04 authoritative for the underlying rules.
  volatility: static
  note: >
    This is the RULE FILE for prompt construction. The actual per-day prompt is SYNTHESISED by
    an LLM using c1_generation_prompt_synthesis.md — that meta-prompt reads THIS file's
    directive_axes and constraints, and the current PieceRecord's spec, and produces the
    image-gen prompt. This indirection exists so tweaks to prompt style (module 07's
    performance loop will propose these) become file edits, not code edits.

rules:
  directive_axes:
    # What each axis contributes to the image-gen prompt. Order matters — earlier axes are
    # earlier in the constructed prompt.
    - axis: content_type
      contributes: "primary subject matter and rendering approach"
      values:
        detailed_representational: "landscape, dense composition, representational detail"
        minimalist_modern: "line work, negative space, abstract composition, minimalist"
        portrait_still_life: "portrait or still-life subject"
    - axis: mood
      contributes: "energy and colour intensity"
      values:
        calm_ordered: "calm, ordered, softened palette, restrained composition"
        bold_active: "bold, high-energy, saturated palette, dynamic composition"
    - axis: color_role
      contributes: "colour treatment specific to the scene role"
      values:
        color_burst: "one saturated hero colour, otherwise restrained"
        accent_highlighter: "colour palette that highlights a single accent tone"
        unifier: "cohesive multi-colour palette that could tie scattered tones together"
        saturator: "reinforces one dominant colour theme with variations"
        line_only: "black, white, grey — no colour; lines and pattern carry the piece"
    - axis: frame_form
      contributes: "compositional shape hint (for how the piece will sit in the frame)"
      values:
        angular: "composition suited to a straight-edged, angular frame"
        rounded: "composition tolerant of or suited to a rounded frame"

  space_tips_modifier:
    citation: "p. 51 (module 04 §2.5a)"
    rule: >
      If the scene's room_shape is narrow / low_ceilinged / small_closed_in, add the
      corresponding line-orientation constraint from module 04's rules/space_tips.yml —
      generation should respect the constraint or downstream weight-balance in module 04
      Step 5 will fail.
    applied_by: llm_synthesis   # the meta-prompt handles this lookup

  do_not_specify:
    # These are decided in Phase 2 by module 04 after the piece exists, not baked into the
    # image. The image is the ART, not the framed piece. Do not include frame material,
    # matting, or physical scale in the generation prompt.
    - "frame material or finish"
    - "matting technique"
    - "physical dimensions or aspect ratio (image generation returns a fixed ratio anyway)"

  constraints:
    negative_prompt: >
      no watermark, no signature, no text unless the style requires typography, no visible
      frame or matting in the image itself, no room or wall around the piece — the art fills
      the frame
    style_reference_use: >
      If your generation provider supports style references (Midjourney sref, Flux img-to-img,
      Ideogram style reference), pass the reference set from A1 as the style reference. If
      not, describe the reference set's characteristics in the prompt.
```

---

## 3. Prompt files

### 3.1 `knowledge_base/prompts/c1_generation_prompt_synthesis.md`

Note — this is a meta-prompt. It runs through the LLM to produce another prompt (which then goes
to the image generator).

```markdown
You are constructing an image-generation prompt for a wall-art print. You are not generating the
image yourself; your output is the text prompt that will be sent to the image-generation API.

The spec for this piece is:

- **Style:** %{style_name}
- **Mood:** %{mood}
- **Content Type:** %{content_type}
- **Frame Form:** %{frame_form}
- **Scene Color Role:** %{color_role}
- **Scene Room Shape:** %{room_shape}

Compose the prompt in this order:

1. Lead with the subject matter and rendering approach (from Content Type).
2. Add the mood layer (energy and palette).
3. Add the colour treatment specific to this scene (from Color Role).
4. Add a compositional shape hint appropriate to the frame form.
5. If room shape is narrow / low_ceilinged / small_closed_in, add the corresponding line
   orientation constraint:
   - narrow → strong vertical lines in the composition
   - low_ceilinged → strong horizontal lines
   - small_closed_in → open, uncluttered composition with visual "breathing room"
6. Add the negative-prompt constraints: no watermark, no signature, no visible frame or matting in
   the image, no room around the piece.

**Do NOT include** in the prompt: frame material, frame finish, matting technique, physical
dimensions, or any information about the room the piece will hang in. The image is the ART, not
the framed-and-hung piece — the frame is decided later in Phase 2.

Return JSON matching the required schema, with the constructed image-generation prompt and a
brief explanation of which axis contributed which phrase.
```

---

## 4. Image-generation adapter interface

### 4.1 The adapter contract

```ruby
# app/services/image_generation/adapter.rb
module ImageGeneration
  Result = Struct.new(:urls, :provider, :model, :estimated_cost_usd, :raw_response, keyword_init: true)

  class GenerationError < StandardError; end

  class Adapter
    # Every concrete adapter implements these three methods, nothing else.
    def name = raise(NotImplementedError)

    # prompt: String — the image-gen prompt built by C1's synthesis step
    # n:      Integer — how many candidates to produce this call (respects batch cap in caller)
    # style_reference: optional Array<String> of reference image URLs, if the provider supports it
    def generate(prompt:, n:, style_reference: []) = raise(NotImplementedError)

    # Best-effort estimate for logging into PieceRecord.step_log. Fine to hard-code a per-image
    # constant per provider — this is for cost tracking, not billing.
    def estimated_cost_usd(n:) = raise(NotImplementedError)

    def self.build
      case ENV.fetch("IMAGE_GEN_PROVIDER", "manual")
      when "manual"    then ManualAdapter.new
      when "replicate" then ReplicateAdapter.new
      else raise GenerationError, "Unknown IMAGE_GEN_PROVIDER=#{ENV['IMAGE_GEN_PROVIDER']}"
      end
    end
  end
end
```

### 4.2 `ReplicateAdapter` — Flux via Replicate

```ruby
# app/services/image_generation/replicate_adapter.rb
module ImageGeneration
  class ReplicateAdapter < Adapter
    # Verify the current Flux model slug against Replicate's docs before running in
    # production — Replicate model slugs and version hashes change without notice.
    # As of this plan's drafting date, the working slug is "black-forest-labs/flux-1.1-pro".
    # A build script should read this from ENV to avoid drift:
    MODEL = ENV.fetch("REPLICATE_MODEL_SLUG", "black-forest-labs/flux-1.1-pro")
    COST_PER_IMAGE_USD = ENV.fetch("REPLICATE_COST_PER_IMAGE", "0.04").to_f

    def name = "replicate:#{MODEL}"

    def generate(prompt:, n:, style_reference: [])
      urls = []

      n.times do
        response = connection.post("predictions") do |req|
          req.body = {
            model: MODEL,
            input: {
              prompt: prompt,
              aspect_ratio: "1:1",
              output_format: "png",
              output_quality: 95
            }.tap { |i| i[:image_prompt] = style_reference.first if style_reference.any? }
          }
        end

        raise GenerationError, "Replicate error #{response.status}: #{response.body}" unless response.success?

        prediction = JSON.parse(response.body)
        output = poll_until_complete(prediction["id"])
        urls.concat(Array(output).flatten)
      end

      Result.new(urls: urls, provider: name, model: MODEL,
                 estimated_cost_usd: estimated_cost_usd(n: n),
                 raw_response: nil)
    end

    def estimated_cost_usd(n:) = (COST_PER_IMAGE_USD * n).round(4)

    private

    def poll_until_complete(id, max_seconds: 180)
      deadline = Time.current + max_seconds
      loop do
        raise GenerationError, "Replicate prediction #{id} timed out" if Time.current > deadline

        resp = connection.get("predictions/#{id}")
        data = JSON.parse(resp.body)
        case data["status"]
        when "succeeded" then return data["output"]
        when "failed", "canceled" then raise GenerationError, "Replicate failed: #{data['error']}"
        end
        sleep 2
      end
    end

    def connection
      @connection ||= Faraday.new(url: "https://api.replicate.com/v1/") do |f|
        f.headers["Authorization"] = "Bearer #{ENV.fetch('REPLICATE_API_KEY')}"
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
```

**Add to `.env` and `.env.example`:**

```bash
IMAGE_GEN_PROVIDER=manual                        # start here; switch to "replicate" when ready
REPLICATE_API_KEY=
REPLICATE_MODEL_SLUG=black-forest-labs/flux-1.1-pro
REPLICATE_COST_PER_IMAGE=0.04
```

### 4.3 `ManualAdapter` — the zero-cost fallback

```ruby
# app/services/image_generation/manual_adapter.rb
module ImageGeneration
  class ManualAdapter < Adapter
    def name = "manual"

    # Writes the prompt to a file and returns immediately with a needs_human flag in the
    # Result. The C1 step surfaces this to the review UI (module 06), where you paste back
    # the image URLs after running the prompt yourself in Midjourney/ChatGPT/anywhere.
    def generate(prompt:, n:, style_reference: [])
      out_dir = Rails.root.join("tmp", "manual_gen_prompts")
      out_dir.mkpath
      file = out_dir.join("prompt_#{Time.current.to_i}.txt")
      file.write(<<~TXT)
        # Manual image-generation prompt
        # Count requested: #{n}
        # Style reference URLs (optional):
        #{style_reference.map { |u| "#     #{u}" }.join("\n")}

        #{prompt}
      TXT

      Result.new(urls: [], provider: "manual", model: "manual",
                 estimated_cost_usd: 0.0,
                 raw_response: { pending: true, prompt_file: file.to_s, n_requested: n })
    end

    def estimated_cost_usd(n:) = 0.0
  end
end
```

**Why the manual adapter isn't a hack:** every module in the plan is buildable and runnable without
spending money on image generation, and the moment you *do* switch to Replicate, the only difference
is one `.env` variable — no code changes. This means Track C is not a bottleneck for building or
testing modules 04–07.

---

## 5. Schema class

```ruby
# app/llm/schemas/track_c/prompt_synthesis_schema.rb
module Schemas
  module TrackC
    class PromptSynthesisSchema < RubyLLM::Schema
      string :image_generation_prompt,
             description: "The final constructed prompt to send to the image-generation API"
      array :axis_contributions,
            description: "Which phrase came from which axis — for auditability" do
        object do
          string :axis,
                 enum: %w[content_type mood color_role frame_form room_shape]
          string :phrase_added
        end
      end
      string :negative_prompt,
             description: "The negative-prompt clause: no watermark, no signature, etc."
    end
  end
end
```

---

## 6. Step implementations

Track C steps operate on a **`PieceRecord`** — this is where the first real piece row is created.
Pass the `PieceRecord` normally.

### 6.1 C1 — Generate art

```ruby
# app/steps/track_c/generate_art.rb
module Steps
  module TrackC
    class GenerateArt < Steps::Base
      step id: "C1",
           mechanism: :image_gen,
           ownership: "[AGENT-ASSISTED — human enforces batch cap]"

      # context: { candidate_count: (optional Integer) }
      # piece: a fresh PieceRecord with style_spec_slug and scene_spec_id set — apply_spec!
      #        must have been called on it already so the axis values are denormalised.
      def perform
        constraints = rules("generation_constraints").rules
        cap  = constraints["batch"]["max_candidates_per_scene"]
        want = [context.fetch(:candidate_count, cap).to_i, cap].min

        if want < 1
          return fail_step("candidate_count must be at least 1", { requested: context[:candidate_count] })
        end

        # === Step 1 — synthesise the prompt ===
        synthesis = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                           .with_schema(Schemas::TrackC::PromptSynthesisSchema)
                           .ask(build_synthesis_prompt).content

        gen_prompt = synthesis["image_generation_prompt"]

        # === Step 2 — call the image generator ===
        adapter = ImageGeneration::Adapter.build
        result  = adapter.generate(prompt: gen_prompt, n: want)

        # Persist the prompt on the piece regardless of adapter outcome, so it's reproducible
        # and available for the review UI even in the manual case.
        piece.update!(
          batch_count: want,
          candidate_urls: result.urls
        )

        if result.raw_response.is_a?(Hash) && result.raw_response[:pending]
          needs_human(
            "IMAGE_GEN_PROVIDER=manual: generate #{want} candidates from the prompt at " \
            "#{result.raw_response[:prompt_file]} and paste the resulting image URLs back " \
            "into this piece via candidate_urls.",
            { prompt_file: result.raw_response[:prompt_file],
              n_requested: want, adapter: adapter.name, prompt: gen_prompt }
          )
        else
          ok({
            candidate_urls: result.urls,
            estimated_cost_usd: result.estimated_cost_usd,
            adapter: adapter.name,
            prompt: gen_prompt,
            axis_contributions: synthesis["axis_contributions"]
          })
        end
      end

      private

      def build_synthesis_prompt
        prompt("c1_generation_prompt_synthesis",
               style_name:   spec.name,
               mood:         piece.mood,
               content_type: piece.content_type,
               frame_form:   piece.frame_form,
               color_role:   piece.color_role,
               room_shape:   piece.room_shape)
      end
    end
  end
end
```

**On the batch cap:** the cap is enforced in code (`[requested, cap].min`), not left to the model
or the caller. `context[:candidate_count]` can request fewer but never more. The reasoning is in the
rule file: an unbounded loop against an image generation API is a real cost risk, and the
*Paradox of Choice* grounding says a larger batch produces a worse cull, not a better one.

**On persisting the prompt:** `PieceRecord.step_log` (from module 00) captures the synthesis output
via `log_step!`, so the prompt used, the axis contributions, and the adapter+cost are all
reconstructible later. This is what module 07's evolution loop reads when Claude proposes tweaks —
without it, "why was this prompt used" becomes guesswork.

### 6.2 C2 — Cull to finalists

```ruby
# app/steps/track_c/cull_to_finalists.rb
module Steps
  module TrackC
    class CullToFinalists < Steps::Base
      step id: "C2",
           mechanism: :human,
           ownership: "[AGENT-ASSISTED — human makes final pick]"

      # context: { finalist_urls: [..], chosen_url: '...' }
      #
      # Two-stage: the human first narrows to finalists (returned as needs_human once), then
      # picks one chosen from those (returned as needs_human again). On the third call, with
      # chosen_url set, the step completes.
      def perform
        candidates = piece.candidate_urls
        return fail_step("no candidates on piece — C1 hasn't produced any", {}) if candidates.empty?

        rules_data = rules("generation_constraints").rules

        finalists_requested = Array(context[:finalist_urls])
        chosen              = context[:chosen_url]

        # === Stage 1: propose finalists ===
        if finalists_requested.empty?
          return needs_human(
            "Cull the batch of #{candidates.size} to at most #{rules_data['finalist_cull']['max_finalists_per_scene']} " \
            "finalists (absolute max #{rules_data['finalist_cull']['absolute_max']}). Set " \
            "finalist_urls on the piece.",
            { candidates: candidates,
              cull_target: rules_data["finalist_cull"]["max_finalists_per_scene"],
              cull_absolute_max: rules_data["finalist_cull"]["absolute_max"] }
          )
        end

        # Validation: finalists must be a subset of candidates, and within cull limits
        invalid = finalists_requested - candidates
        if invalid.any?
          return fail_step("finalist_urls contains URLs not in candidate_urls: #{invalid.take(3).inspect}", {})
        end

        absolute_max = rules_data["finalist_cull"]["absolute_max"]
        if finalists_requested.size > absolute_max
          return fail_step(
            "Cull produced #{finalists_requested.size} finalists; absolute maximum is #{absolute_max}. " \
            "The cull discipline is the point of this step — narrow further.",
            { finalists_count: finalists_requested.size, absolute_max: absolute_max }
          )
        end

        piece.update!(finalist_urls: finalists_requested)

        # === Stage 2: pick one chosen ===
        if chosen.blank?
          return needs_human(
            "Pick ONE finalist as the day's chosen piece. This becomes PieceRecord.chosen_url " \
            "and flows into Phase 2 — no more finalists carry forward.",
            { finalists: finalists_requested }
          )
        end

        unless finalists_requested.include?(chosen)
          return fail_step("chosen_url is not in finalist_urls", { chosen: chosen, finalists: finalists_requested })
        end

        piece.update!(chosen_url: chosen)
        ok({ finalist_urls: finalists_requested, chosen_url: chosen })
      end
    end
  end
end
```

**Grounding for the two-stage flow:** the source doc's C2 step is one step but with two decisions
inside it — narrow to finalists, then pick one chosen. Splitting them here keeps the human review
surface small: the reviewer isn't asked to do both at once, which is the *Paradox of Choice*
anti-pattern this rule was built to avoid.

---

## 7. Track C run order (per day, per scene template)

```
[Track A complete: style_level locked in style_specs/<slug>.yml]
[Track B complete: axes locked for this scene template]
[PieceRecord created with style_spec_slug + scene_spec_id, apply_spec! called]

C1  (synthesise prompt → call image adapter → produce candidate_urls)
    ├── ManualAdapter: needs_human (paste back URLs)
    └── Replicate/other:  ok, N candidates on the piece
      ↓
C2  Stage 1: needs_human (pick 3–4 finalists from N candidates)
      ↓
C2  Stage 2: needs_human (pick 1 chosen from finalists)
      ↓
Phase 2 (module 04) — the piece is now ready for placement.
```

C2's two-stage flow means module 06's review UI will show a Track C piece in three possible states:
`awaiting_human:c1_manual_gen` (if manual adapter), `awaiting_human:c2_finalists`, and
`awaiting_human:c2_chosen`. Modules 06 uses these string states to route the reviewer to the right
UI screen.

---

## 8. Verification

```bash
# 1. Rule files exist and carry citations
bin/rails runner '
  %w[generation_constraints generation_prompt_template].each do |n|
    r = KnowledgeBase::RuleSet.load(n)
    puts "#{n}: source=#{r.meta["source"].present?} citation=#{r.meta["citation"].present?}"
  end
'

# 2. Batch cap, cull, and chosen counts are the documented values
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("generation_constraints").rules
  puts "cap=#{r["batch"]["max_candidates_per_scene"]}"    # expect 10
  puts "finalists=#{r["finalist_cull"]["max_finalists_per_scene"]}"  # expect 3
  puts "finalists_abs=#{r["finalist_cull"]["absolute_max"]}"          # expect 4
  puts "chosen=#{r["chosen"]["count"]}"                                # expect 1
'

# 3. Prompt template covers the four expected directive axes
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("generation_prompt_template").rules
  axes = r["directive_axes"].map { |a| a["axis"] }
  puts "axes=#{axes.inspect}"   # expect [content_type, mood, color_role, frame_form]
'

# 4. C1 synthesis prompt renders with all six interpolations
bin/rails runner '
  puts format(Pipeline::KB_ROOT.join("prompts/c1_generation_prompt_synthesis.md").read,
              style_name: "Japandi", mood: "calm_ordered",
              content_type: "minimalist_modern", frame_form: "angular",
              color_role: "line_only", room_shape: "none").size
'

# 5. Step classes match registry
bin/rails runner '
  reg = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  reg["phase_1"]["track_c"]["steps"].each do |s|
    k = s["klass"].constantize
    ok = k.step_id == s["id"] && k.ownership == s["ownership"]
    puts "#{s["id"]}: #{ok ? "ok" : "MISMATCH"}"
  end
'

# 6. Adapter factory picks the right class per env
bin/rails runner '
  ENV["IMAGE_GEN_PROVIDER"] = "manual"
  puts ImageGeneration::Adapter.build.name    # expect "manual"
  ENV["IMAGE_GEN_PROVIDER"] = "replicate"
  puts ImageGeneration::Adapter.build.name    # expect "replicate:black-forest-labs/flux-1.1-pro"
  ENV["IMAGE_GEN_PROVIDER"] = "manual"
'

# 7. ManualAdapter writes a prompt file and returns pending, without any API call
bin/rails runner '
  a = ImageGeneration::ManualAdapter.new
  r = a.generate(prompt: "test prompt", n: 3)
  puts "urls=#{r.urls.inspect}"                                        # expect []
  puts "cost=#{r.estimated_cost_usd}"                                  # expect 0.0
  puts "pending=#{r.raw_response[:pending]}"                            # expect true
  puts "file_exists=#{File.exist?(r.raw_response[:prompt_file])}"      # expect true
'

# 8. C1 enforces the batch cap even if a higher count is requested
bin/rails runner '
  # This requires a PieceRecord with a style_spec — use the b-test spec from module 02 if it exists
  s = KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
    slug: "c-test", name: "C-Test", mood: "calm_ordered",
    content_type: "minimalist_modern", frame_form: "angular")
  scene = KnowledgeBase::SceneSpecWriter.write_scene_axes(
    style_slug: "c-test", scene_id: "s1", scene_name: "S1", template_ref: "x.yml",
    axes: { wall_condition: "neutral", furniture_weight: "light", room_type: "seated_room",
            room_shape: "none", space_math: "single", color_role: "line_only" })
  piece = PieceRecord.new(style_spec_slug: "c-test", scene_spec_id: "s1",
                          kb_version: "dirty:test", status: "pending")
  piece.apply_spec!(KnowledgeBase::StyleSpec.load("c-test"),
                    KnowledgeBase::StyleSpec.load("c-test").scene("s1"))
  piece.save!
  ENV["IMAGE_GEN_PROVIDER"] = "manual"
  result = Steps::TrackC::GenerateArt.call(piece: piece, context: { candidate_count: 999 })
  puts "batch_count=#{piece.reload.batch_count}"    # expect 10, not 999
  piece.destroy!
  File.delete(Pipeline::KB_ROOT.join("style_specs/c-test.yml").to_s) rescue nil
'

# 9. C2 rejects a finalist not in candidate_urls, and rejects too many finalists
bin/rails runner '
  # After running C1 above, build a piece with candidates set
  piece = PieceRecord.create!(style_spec_slug: "c-test", scene_spec_id: "s1",
                              kb_version: "dirty:test", status: "pending",
                              candidate_urls: %w[a b c d])
  r = Steps::TrackC::CullToFinalists.call(piece: piece,
        context: { finalist_urls: %w[a b e], chosen_url: nil })
  puts "rejects invalid finalist: #{r.failed?}"    # expect true
  r = Steps::TrackC::CullToFinalists.call(piece: piece,
        context: { finalist_urls: %w[a b c d], chosen_url: nil })
  puts "rejects >absolute_max: #{r.failed?}"       # expect true (4 == absolute_max is OK; >4 fails)
  piece.destroy!
'
```

**Also verify by hand:**
- `IMAGE_GEN_PROVIDER=manual` is the default in `.env.example` — a fresh clone should never
  accidentally spend money on image generation before the developer changes it.
- The C1 prompt persisted to `step_log` matches the prompt actually sent to the image API — this
  is what module 07 will read later.
- Neither C1 nor C2 references any Phase 2 rule file; Track C reads style + scene axes only.

---

## 9. Manifest coverage

| ID | Item | Where |
|---|---|---|
| C1, C2 | Both Track C steps with verbatim ownership tags | §6 |
| — | Batch cap (10/scene/day) and cull rule (3–4 finalists → 1 chosen) | §2.1, enforced §6.1 & §6.2 |
| — | *Paradox of Choice* grounding for the batch cap | §2.1 `meta.citation`, §1.3 |
| — | *This Is Marketing* grounding for the finalist commitment | §2.1 `meta.citation`, §1.3 |
| — | Prompt-construction rules that read from the axes Track A/B produced | §2.2 |
| — | Space-tips modifier for narrow/low_ceilinged/small_closed_in room shapes | §2.2 `space_tips_modifier`, §3.1 step 5 |
| — | Do-not-specify list (frame material / matting / physical scale) | §2.2 `do_not_specify` |
| — | Negative-prompt template (no watermark, no signature, etc.) | §2.2 `constraints.negative_prompt` |
| — | Provider-agnostic adapter with manual fallback | §4 |

**Deferred to other modules:** the actual frame material, contour, matting, eye level, and
compositing math all live in module 04 — Track C's output is the unframed art. The listing photos,
title, and description live in module 05. The performance-loop tweaks to the prompt template live in
module 07.
