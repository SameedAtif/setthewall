# Module 01 — Phase 1, Track A: Style-Level Axes

> **Self-contained.** Every rule, prompt, and criterion this module needs is written out below
> verbatim. Do not search the internet for the domain content — it is all here. Build exactly what is
> specified.

---

## Contract

**Depends on:** module 00 (`Steps::Base`, `KnowledgeBase::StyleSpec`, `KnowledgeBase::RuleSet`,
`Pipeline::KB_ROOT`, `config/step_registry.yml`) and module 00b (`Search::ReasonedRunner`,
`Tools::WebSearch`) — A0 and A1 both require live, verified web search and must not answer from
model memory.

**Provides:**
- `knowledge_base/rules/reference_set_criteria.yml`
- `knowledge_base/rules/mood_markers.yml`
- `knowledge_base/rules/content_type.yml`
- `knowledge_base/rules/frame_form.yml`
- `knowledge_base/prompts/a0_style_validation.md`
- `knowledge_base/prompts/a1_reference_set.md`
- `knowledge_base/prompts/a2_mood.md`
- `knowledge_base/prompts/a3_content_type.md`
- `knowledge_base/prompts/a4_frame_form.md`
- `app/steps/track_a/*.rb` (6 step classes: A0–A5)
- `app/llm/schemas/track_a/*.rb`
- `KnowledgeBase::StyleSpecWriter` — the only code permitted to write `style_specs/*.yml` style-level keys

**Consumed by:** module 02 (writes scene axes into the same file), modules 03/04/05 (read the spec).

**Must not:** touch `piece_records` (Track A runs before any piece exists), define scene-level axes
(module 02 owns those), or write to `knowledge_base/rules/` files owned by modules 04/05.

---

## 1. What Track A is

Track A determines the **three style-level axes** — Mood, Content Type, Frame Form — that are set
**once per style** and reused for every piece in that style. It runs infrequently: only when you
introduce a new style (Japandi, boho, mid-century, etc.).

**Every step in Track A is human-gated.** This is deliberate and must not be optimised away. The
style-spec axis values encode the brand's actual point of view; letting an agent infer them unattended
produces generic output, which defeats the entire premise of a niche. The agent's job here is to run
methodology and propose classifications — the human's job is to confirm or reject each one.

Cadence: `per_style`. Track A does not run daily.

---

## 2. Rule files to create

### 2.1 `knowledge_base/rules/reference_set_criteria.yml`

```yaml
meta:
  source: "Phase 1, Step A1 — Build a reference set"
  citation: >
    Not grounded in the project's book corpus (arrangement book or business books) — this is
    a research methodology, not a book-derived rule. It IS source-disciplined in its own
    right: every output image requires attribution from 2+ independent live web sources
    (retailer style guide, design publication, or attributed Pinterest pin), with a per-source
    cap of 3-4 images. See image_requirements below.
  volatility: static
  note: >
    This step is explicitly flagged in the source doc as practical guidance rather than a
    documented rule from the arrangement books or the business books. Treat it as a working
    convention, not a cited rule. Distinct from "unsourced" in the sense of ungrounded —
    A1's OUTPUT is held to a stricter sourcing bar (2+ independent live sources per image)
    than most rules in this project, which cite a single book passage.

rules:
  search_process:
    - order: 1
      action: "Search retailer style guides first"
      detail: >
        e.g. "West Elm [STYLE NAME] style guide", "CB2 [STYLE NAME]", "IKEA [STYLE NAME]".
        These are authoritative named-style descriptions, not merely visually-similar-but-
        mislabeled content.
    - order: 2
      action: "Search Pinterest with three separate queries"
      detail: >
        "[STYLE NAME] wall art", "[STYLE NAME] gallery wall", and "[STYLE NAME] living room"
        (or the relevant space). Three separate queries, not one, to catch both product-only
        and in-situ shots.
    - order: 3
      action: "Search 1-2 interior design blogs or magazines"
      detail: >
        Look for written characteristic descriptions of the style (palette, materials, mood
        words) to cross-check what the images seem to show against what is explicitly named.
    - order: 4
      action: "Cap any single source at roughly 3-4 images"
      detail: >
        One shop, one blog, or one Pinterest board contributes at most 3-4 images to the final
        set. Mirrors the A0 principle of not trusting one source's signal.

  # Four requirements an image must meet to enter the reference set.
  image_requirements:
    - id: framed_in_situ
      requirement: >
        Shows the piece actually framed and/or hung in a room, not just a flat product photo
        on a white background.
      why: >
        Frame Form (A4) and Mood (A2) cannot be judged without seeing how the piece is
        actually framed and styled.
    - id: closeup_proportion
      requirement: >
        At least a third of the set is close-up / product-only shots of the art itself.
      why: >
        Needed to judge Content Type (A3) — representational vs. minimalist vs. portrait/
        still-life detail can be hard to read in a full room shot.
    - id: multi_source_attribution
      requirement: >
        Attributed to the target style by more than one independent source — appears under
        that style's name in at least 2 of the searches above, not just one shop's own
        product tagging.
      why: >
        A single shop's SEO-tagged listing is not reliable evidence the piece actually reads
        as that style. Same logic as not trusting one bestseller badge in A0.
    - id: traceable_source
      requirement: >
        Source is a retailer, a design publication, or a Pinterest pin with a real
        originating source — not an unattributed re-post.
      why: "Keeps the reference set traceable if it needs rechecking later."

  validation:
    rule: >
      References span multiple independent sources (per the cap above), include both in-situ
      and close-up shots, and each image is attributable to the style by more than one source
      — not assembled from a single board or shop.
```

### 2.2 `knowledge_base/rules/mood_markers.yml`

```yaml
meta:
  source: "Phase 1, Step A2 — Sort into Mood"
  citation: "how_to_arrange_pictures / at_home_with_pictures — p. 27-28, p. 68-69, p. 74, p. 81, p. 88, p. 89"
  volatility: static
  provenance_warning: >
    The book's own mood passage (p. 56-57, framed around "Are you a rule-follower or a
    rule-breaker?") is a personal gut-check rather than an observable checklist, AND p. 56
    carries OCR noise in the source scan. Its exact wording is directionally reliable only,
    not a verbatim quote. The four markers below are used INSTEAD, drawn from cleaner-OCR
    passages elsewhere in the same book.

rules:
  axis: mood
  values: [calm_ordered, bold_active]

  # Four concrete, observable markers. Score each reference image against all four.
  markers:
    - id: wall_art_color_relationship
      name: "Wall/art color relationship"
      calm_ordered: "Complementary or softened-intensity pairing"
      bold_active: >
        Deliberate tension — wall and art colors that are not complementary, creating
        "vibration" / energy
      citation: "p. 88"
    - id: display_density
      name: "Density of the display"
      calm_ordered: >
        One vivid centerpiece with everything else quieted down (p. 89), or a formal cluster
        with an anchoring central piece (p. 74)
      bold_active: >
        Salon-style — many pieces and frames of different styles "poured onto the wall"
        (p. 74, p. 81)
      citation: "p. 74, p. 81, p. 89"
    - id: arrangement_symmetry
      name: "Arrangement symmetry"
      calm_ordered: "Precise, symmetric alignment"
      bold_active: "Slightly off-kilter, asymmetric arrangement"
      citation: "p. 68-69"
    - id: framing_weight
      name: "Framing weight"
      calm_ordered: "Quiet, subtle frames even on a focal piece"
      bold_active: "Oversized / impressive frames used to command attention"
      citation: "p. 27-28"

  scoring:
    rule: >
      Score each reference image against the four markers. A set that lands mostly in one
      column supports that Mood value.
    mixed_result: >
      A genuinely mixed scorecard means the reference set itself is not focused enough yet.
      Narrow it (return to A1) rather than forcing a call.

  validation:
    rule: >
      Can you point to 3+ reference images that clearly support the chosen mood against at
      least TWO of the four markers, not just a general impression?
    on_fail: "Return to A1 and narrow the reference set before locking."
    grounding: >
      The Paradox of Choice — satisficer principle: commit to a bar, do not keep the option
      open indefinitely.
```

### 2.3 `knowledge_base/rules/content_type.yml`

```yaml
meta:
  source: "Phase 1, Step A3 — Sort into Content Type"
  citation: "how_to_arrange_pictures / at_home_with_pictures, p. 19"
  volatility: static

rules:
  axis: content_type
  values: [detailed_representational, minimalist_modern, portrait_still_life]

  definitions:
    detailed_representational:
      description: "Landscapes, dense imagery, representational subject matter with detail"
      predicted_contour: inward_sloping_beveled
    minimalist_modern:
      description: "Line work, negative space, abstract composition"
      predicted_contour: flush_level_plane
    portrait_still_life:
      description: "Portrait or still-life subject matter"
      predicted_contour: outward_sloping

  validation:
    rule: >
      Re-check the frame contour prediction against what the references actually show framed.
      If the predicted contour does not match what you see in the reference images, the
      Content Type call is probably wrong.
    note: >
      The contour rule itself lives in module 04 (rules/frame_form_contour.yml, Phase 2 §2.2).
      The predicted_contour values above are duplicated here ONLY as a validation cross-check
      for A3. Module 04's file is authoritative for actual frame decisions. If the two ever
      disagree, module 04 wins and this file must be corrected.
```

### 2.4 `knowledge_base/rules/frame_form.yml`

```yaml
meta:
  source: "Phase 1, Step A4 — Sort into Frame Form"
  citation: "how_to_arrange_pictures / at_home_with_pictures, p. 19"
  volatility: static

rules:
  axis: frame_form
  values: [angular, rounded]

  definitions:
    angular:
      description: "Angular / straight-edged — crisp, geometric perimeter"
      reads_as: "more modern / minimalist"
    rounded:
      description: "Rounded / softer — curved, gentler perimeter"
      reads_as: "softer / more traditional"

  determination:
    rule: >
      Look at how the style is typically framed across the reference set — angular or rounded.
    consistency_check: "Consistent across most references, or mixed?"
    tiebreaker: >
      If mixed, Mood is the tiebreaker. Bold moods more often tolerate mixed / salon-style
      framing; calm moods should converge on one form.
    note: >
      The book does not hard-gate this axis. Treat it as a style-spec choice made once per
      style, not a per-piece decision.
```

---

## 3. Prompt files to create

### 3.1 `knowledge_base/prompts/a0_style_validation.md`

This is the research brief. It is reproduced **verbatim** from the source document — do not reword it.

```markdown
Research what types of wall art designs are most likely to sell well in the **%{style_name}** style
for a wall-hanging/print business, using a methodology that avoids the pitfalls of naively trusting
Etsy "bestseller" labels (skewed by shop-level SEO/marketing strength, listings with hundreds of
size/color variants inflating apparent demand, and recency-based badge algorithms rather than true
sustained demand).

Methodology:

1. Sample wall art listings across many different independent Etsy shops (not one bestseller list)
   searching **%{style_name}** wall art, plus 2-3 closely adjacent style terms if relevant.
2. Identify recurring design attributes across listings from *different* shops — subject matter,
   color palette, composition style, texture/medium look.
3. Cross-check the style's demand signal against at least one independent platform (Pinterest
   trend/search volume, Google Trends) — a pattern holding across multiple independent sources is
   more trustworthy than any single platform.
4. Estimate competition density (approximate listing count) alongside demand, and compute a
   demand-to-competition ratio — a smaller-volume style with low competition can beat a
   high-volume, oversaturated one.
5. Output a findings table: style/theme → recurs across N independent shops → approximate
   competition density → confirmed (or not) on the cross-check platform → recommended
   demand-to-competition verdict.
```

### 3.2 `knowledge_base/prompts/a1_reference_set.md`

```markdown
You are assembling a reference image set for the interior/art style: **%{style_name}**.

Run this search process in order:

1. Search retailer style guides first — "West Elm %{style_name} style guide", "CB2 %{style_name}",
   "IKEA %{style_name}". These are authoritative named-style descriptions rather than merely
   visually-similar-but-mislabeled content.
2. Search Pinterest with three separate queries: "%{style_name} wall art", "%{style_name} gallery
   wall", "%{style_name} living room". Three separate queries, not one — this catches both
   product-only and in-situ shots.
3. Search 1-2 interior design blogs or magazines for written characteristic descriptions of the
   style (palette, materials, mood words), to cross-check what the images show against what is
   explicitly named.
4. Cap any single source (one shop, one blog, one Pinterest board) at roughly 3-4 images.

An image qualifies for the set only if it meets ALL of these:

- Shows the piece actually framed and/or hung in a room, not just a flat product photo on white.
- Attributed to %{style_name} by more than one independent source — it appears under that style's
  name in at least 2 of the searches above, not just one shop's own product tagging.
- Source is a retailer, a design publication, or a Pinterest pin with a real originating source
  (not an unattributed re-post).

Additionally, at least a third of the final set must be close-up / product-only shots of the art
itself — these are needed later to judge subject matter and rendering style, which is hard to read
in a full room shot.

Return candidates as JSON matching the required schema. Do not include images you cannot attribute
to at least two independent sources.
```

### 3.3 `knowledge_base/prompts/a2_mood.md`

```markdown
Classify the mood of this style's reference set as either calm/ordered or bold/active.

Do NOT judge on general impression. Score the images against these four specific markers:

1. **Wall/art color relationship** — calm: complementary or softened-intensity pairing.
   bold: deliberate tension, wall and art colors that are not complementary, creating vibration
   or energy.
2. **Density of the display** — calm: one vivid centerpiece with everything else quieted down, or a
   formal cluster with an anchoring central piece. bold: salon-style, many pieces and frames of
   different styles poured onto the wall.
3. **Arrangement symmetry** — calm: precise, symmetric alignment. bold: slightly off-kilter,
   asymmetric arrangement.
4. **Framing weight** — calm: quiet, subtle frames even on a focal piece. bold: oversized or
   impressive frames used to command attention.

For each marker, report which column the set lands in and how many images support that reading.

A set that lands mostly in one column supports that mood value. If the scorecard is genuinely mixed,
do NOT force a call — report `mixed` and say so. A mixed scorecard means the reference set is not
focused enough yet and needs narrowing, which is a human decision.

Return JSON matching the required schema.
```

### 3.4 `knowledge_base/prompts/a3_content_type.md`

```markdown
Classify this style's reference imagery into exactly one content type, based on the actual subject
matter and rendering style shown:

- **detailed_representational** — landscapes, dense imagery, representational subject matter
  carrying detail.
- **minimalist_modern** — line work, negative space, abstract composition.
- **portrait_still_life** — portrait or still-life subject matter.

Then perform this cross-check: each content type predicts a frame contour —
detailed_representational predicts inward-sloping/beveled framing; minimalist_modern predicts
flush/level-plane; portrait_still_life predicts outward-sloping.

Look at how the reference pieces are ACTUALLY framed. If the framing you observe does not match the
contour predicted by your classification, the classification is probably wrong — report the
mismatch rather than ignoring it.

Return JSON matching the required schema.
```

### 3.5 `knowledge_base/prompts/a4_frame_form.md`

```markdown
Look at how this style is typically framed across the reference set. Classify the frame form as:

- **angular** — straight-edged, crisp, geometric perimeter. Reads more modern/minimalist.
- **rounded** — curved, gentler, softer perimeter. Reads softer/more traditional.

Report whether the form is consistent across most references, or mixed.

If it is mixed, do not pick arbitrarily. This style's mood has already been determined as
**%{mood}**. Apply the tiebreaker: bold moods more often tolerate mixed or salon-style framing;
calm moods should converge on one form. State explicitly that you used the tiebreaker.

Return JSON matching the required schema.
```

---

## 4. Schema classes

```ruby
# app/llm/schemas/track_a/style_validation_schema.rb
module Schemas
  module TrackA
    class StyleValidationSchema < RubyLLM::Schema
      array :findings do
        object do
          string :theme,                 description: "Style or theme identified"
          integer :independent_shops,    description: "Number of DIFFERENT shops it recurs across"
          string :competition_density,   description: "Approximate listing count or density band"
          string :cross_check_platform,  description: "Platform used for the independent cross-check"
          boolean :cross_check_confirmed
          string :demand_to_competition_verdict
        end
      end
      string :recommended_style_focus
      string :methodology_caveats, description: "Any limits on how reliable these findings are"
    end
  end
end
```

```ruby
# app/llm/schemas/track_a/reference_set_schema.rb
module Schemas
  module TrackA
    class ReferenceSetSchema < RubyLLM::Schema
      array :images do
        object do
          string :url
          string :source_type, enum: %w[retailer design_publication pinterest_attributed]
          string :source_name
          array :attributing_sources, of: :string,
                description: "The independent sources that attribute this to the style. Must be 2+."
          string :shot_type, enum: %w[in_situ closeup]
        end
      end
      integer :closeup_count
      integer :total_count
      array :sources_used, of: :string
    end
  end
end
```

```ruby
# app/llm/schemas/track_a/mood_schema.rb
module Schemas
  module TrackA
    class MoodSchema < RubyLLM::Schema
      string :mood, enum: %w[calm_ordered bold_active mixed],
             description: "'mixed' means the scorecard did not resolve — do not force a call"

      array :marker_scores do
        object do
          string :marker, enum: %w[
            wall_art_color_relationship display_density arrangement_symmetry framing_weight
          ]
          string :lands_in, enum: %w[calm_ordered bold_active unclear]
          integer :supporting_image_count
          string :evidence, description: "What in the images supports this reading"
        end
      end

      integer :markers_supporting_chosen_mood,
              description: "How many of the 4 markers support the chosen value. Validation needs 2+."
      integer :clearly_supporting_images,
              description: "Images clearly supporting the chosen mood. Validation needs 3+."
    end
  end
end
```

```ruby
# app/llm/schemas/track_a/content_type_schema.rb
module Schemas
  module TrackA
    class ContentTypeSchema < RubyLLM::Schema
      string :content_type,
             enum: %w[detailed_representational minimalist_modern portrait_still_life]
      string :predicted_contour, enum: %w[inward_sloping_beveled flush_level_plane outward_sloping]
      string :observed_contour,
             enum: %w[inward_sloping_beveled flush_level_plane outward_sloping mixed unclear]
      boolean :contour_cross_check_passed
      string :reasoning
    end
  end
end
```

```ruby
# app/llm/schemas/track_a/frame_form_schema.rb
module Schemas
  module TrackA
    class FrameFormSchema < RubyLLM::Schema
      string :frame_form, enum: %w[angular rounded]
      string :consistency, enum: %w[consistent mixed]
      boolean :tiebreaker_used, description: "True if mood was used to resolve a mixed reading"
      string :reasoning
    end
  end
end
```

---

## 5. `KnowledgeBase::StyleSpecWriter`

The **only** code permitted to write style-level keys into `style_specs/*.yml`. Module 02 has a
parallel writer for scene keys; the two must not overlap.

```ruby
# app/knowledge_base/style_spec_writer.rb
module KnowledgeBase
  class StyleSpecWriter
    def self.create_or_update_style_level(slug:, name:, mood:, content_type:, frame_form:)
      path = Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml")

      doc = path.exist? ? YAML.safe_load_file(path, permitted_classes: [Date]) : {}
      doc["slug"]      = slug
      doc["name"]      = name
      doc["locked_at"] = Date.current.to_s
      doc["style_level"] = {
        "mood"         => mood.to_s,
        "content_type" => content_type.to_s,
        "frame_form"   => frame_form.to_s
      }
      doc["scenes"] ||= {}   # module 02 fills this; never clear it here

      validate_values!(doc["style_level"])

      path.dirname.mkpath
      path.write(<<~HEADER + doc.to_yaml.sub(/\A---\n/, ""))
        # Style Spec — style-level axes set by Phase 1 Track A.
        # Scene axes are appended by Track B (module 02). Do not hand-edit scene keys here
        # without also re-running Track B's validation.
        ---
      HEADER

      StyleSpec.load(slug)
    end

    def self.validate_values!(style_level)
      StyleSpec::STYLE_LEVEL_AXES.each do |axis|
        value = style_level[axis.to_s]
        allowed = StyleSpec::ALLOWED[axis]
        next if allowed.include?(value.to_s)

        raise IncompleteSpecError, "style_level.#{axis}='#{value}' not in #{allowed}"
      end
    end
  end
end
```

---

## 6. Step implementations

All six steps are human-gated. Each returns `needs_human` with the agent's proposal in `data`; a
person confirms via module 06's review UI before the next step runs.

Track A steps operate on a **style slug**, not a `PieceRecord` (no piece exists yet). Pass
`piece: nil` and put the style context in `context`.

### 6.1 A0 — Validate the style is worth pursuing

```ruby
# app/steps/track_a/validate_style.rb
module Steps
  module TrackA
    class ValidateStyle < Steps::Base
      step id: "A0",
           mechanism: :llm_text,
           ownership: "[AGENT-READY for the research — human confirms the go/no-go]"

      # context: { style_name:, style_slug: }
      def perform
        brief = prompt("a0_style_validation", style_name: context.fetch(:style_name))

        result = Search::ReasonedRunner.call(
          model: Pipeline::TEXT_MODEL,
          schema: Schemas::TrackA::StyleValidationSchema,
          task: "You are validating whether a wall-art style is worth committing production to.",
          question: brief,
          max_rounds: 8   # A0's methodology needs: 1 style search + 2-3 adjacent terms +
                           # 1 cross-check platform + competition-density lookups
        )

        needs_human(
          "Read the demand-to-competition findings and make the go/no-go call. The agent ran " \
          "#{result[:search_calls_made]} live searches; committing a week's production to this " \
          "style is your decision, not the agent's.",
          { findings: result[:content], search_calls_made: result[:search_calls_made], brief: brief }
        )
      rescue Search::NoSearchPerformedError => e
        fail_step("A0 could not complete: #{e.message}", { brief: brief })
      end
    end
  end
end
```

**Grounding (record in the class as a comment):**
- *This Is Marketing*, Ch. 4 "The Smallest Viable Market" and Ch. 8 "More of the Who: Seeking the
  Smallest Viable Market" — the smallest-viable-audience principle argues for a defensible specific
  position over chasing the highest-volume category.
- *The Paradox of Choice* — the maximizer trap is chasing "the best" trend signal instead of a
  genuinely defensible one.

**Validation gate the human must apply:** can you name the specific demand-to-competition finding
that justifies this style — not just "it's popular"?

> **Search infrastructure:** A0 uses `Search::ReasonedRunner` (module 00b), which mechanically
> refuses to return an answer if the model never actually called the search tool — see 00b §4. This
> replaces an earlier, unverified assumption that a built-in `RubyLLM::Tools::WebSearch` existed; it
> does not. A0 answered from memory with no search defeats the entire purpose of this step, so this
> is enforced in code, not left as an instruction the model could skip under load.

### 6.2 A1 — Build a reference set

```ruby
# app/steps/track_a/build_reference_set.rb
module Steps
  module TrackA
    class BuildReferenceSet < Steps::Base
      step id: "A1",
           mechanism: :llm_text,
           ownership: "[AGENT-ASSISTED — human curates]"

      MIN_CLOSEUP_FRACTION = 1.0 / 3

      def perform
        criteria = rules("reference_set_criteria")
        text     = prompt("a1_reference_set", style_name: context.fetch(:style_name))

        search_result = Search::ReasonedRunner.call(
          model: Pipeline::TEXT_MODEL,
          schema: Schemas::TrackA::ReferenceSetSchema,
          task: "You are assembling a curated reference-image set for a wall-art style, following " \
                "the search process and per-image requirements given below exactly.",
          question: text,
          max_rounds: 8   # 1 retailer-guide search + 3 distinct Pinterest queries + 1-2 blog
                           # searches, per the source's own 4-step process
        )
        result = search_result[:content]
        issues = validate_set(result)

        needs_human(
          "Curate the reference set (#{search_result[:search_calls_made]} live searches performed). " \
          "#{issues.any? ? "Automated checks flagged: #{issues.join('; ')}" : 'Automated checks passed.'}",
          { candidates: result, issues: issues, criteria: criteria.rules["image_requirements"] }
        )
      rescue Search::NoSearchPerformedError => e
        fail_step("A1 could not complete: #{e.message}", { text: text })
      end

      private

      # Mechanical checks only. The curation judgment stays with the human.
      def validate_set(result)
        issues = []
        images = result["images"] || []

        if images.empty?
          issues << "no candidate images returned"
          return issues
        end

        closeups = images.count { |i| i["shot_type"] == "closeup" }
        if closeups.to_f / images.size < MIN_CLOSEUP_FRACTION
          issues << "only #{closeups}/#{images.size} close-ups (need at least a third)"
        end

        weak = images.select { |i| (i["attributing_sources"] || []).size < 2 }
        issues << "#{weak.size} image(s) attributed by fewer than 2 independent sources" if weak.any?

        by_source = images.group_by { |i| i["source_name"] }
        over = by_source.select { |_, v| v.size > 4 }.keys
        issues << "source cap exceeded (max ~4 each): #{over.join(', ')}" if over.any?

        issues << "in-situ shots missing" if images.none? { |i| i["shot_type"] == "in_situ" }

        issues
      end
    end
  end
end
```

### 6.3 A2 — Sort into Mood

```ruby
# app/steps/track_a/sort_mood.rb
module Steps
  module TrackA
    class SortMood < Steps::Base
      step id: "A2",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms]"

      REQUIRED_MARKERS = 2   # of 4
      REQUIRED_IMAGES  = 3

      # context: { reference_images: [urls] }
      def perform
        images = context.fetch(:reference_images)

        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackA::MoodSchema)
                        .ask(prompt("a2_mood"), with: images).content

        if result["mood"] == "mixed"
          return needs_human(
            "Mood scorecard came back mixed. Per the rule, do not force a call — narrow the " \
            "reference set and re-run A1 rather than picking one.",
            { result: result, recommended_action: "return_to_a1" }
          )
        end

        unless validation_passes?(result)
          return needs_human(
            "Mood proposed as #{result['mood']}, but the validation bar was not met " \
            "(needs 3+ clearly supporting images across 2+ of the 4 markers). " \
            "Consider narrowing the reference set.",
            { result: result, recommended_action: "return_to_a1" }
          )
        end

        needs_human(
          "Confirm mood: #{result['mood']}. Check the marker evidence before accepting.",
          { result: result, recommended_action: "confirm" }
        )
      end

      private

      def validation_passes?(r)
        r["markers_supporting_chosen_mood"].to_i >= REQUIRED_MARKERS &&
          r["clearly_supporting_images"].to_i >= REQUIRED_IMAGES
      end
    end
  end
end
```

**Why the validation is enforced in code:** the source rule is explicit that a mixed or weakly
supported scorecard means the *reference set* is not focused enough, and the correct action is to
narrow it — not to pick the closer of the two moods. Left to prose, this rule gets skipped under time
pressure. Grounding: *The Paradox of Choice* satisficer principle — commit to a bar rather than
keeping the option open indefinitely.

### 6.4 A3 — Sort into Content Type

```ruby
# app/steps/track_a/sort_content_type.rb
module Steps
  module TrackA
    class SortContentType < Steps::Base
      step id: "A3",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackA::ContentTypeSchema)
                        .ask(prompt("a3_content_type"), with: context.fetch(:reference_images))
                        .content

        unless result["contour_cross_check_passed"]
          return needs_human(
            "Content Type proposed as #{result['content_type']}, but the frame-contour " \
            "cross-check FAILED (predicted #{result['predicted_contour']}, observed " \
            "#{result['observed_contour']}). Per the rule, a contour mismatch means the " \
            "Content Type call is probably wrong.",
            { result: result, recommended_action: "reconsider" }
          )
        end

        needs_human("Confirm content type: #{result['content_type']}.",
                    { result: result, recommended_action: "confirm" })
      end
    end
  end
end
```

### 6.5 A4 — Sort into Frame Form

```ruby
# app/steps/track_a/sort_frame_form.rb
module Steps
  module TrackA
    class SortFrameForm < Steps::Base
      step id: "A4",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — human confirms]"

      # context: { reference_images:, mood: }  — mood must already be confirmed by A2
      def perform
        mood = context.fetch(:mood)

        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackA::FrameFormSchema)
                        .ask(prompt("a4_frame_form", mood: mood),
                             with: context.fetch(:reference_images)).content

        note = if result["consistency"] == "mixed"
                 "Framing was mixed across references; resolved using the mood tiebreaker " \
                 "(mood=#{mood}). Bold moods tolerate mixed framing; calm moods should converge."
               else
                 "Framing was consistent across references."
               end

        needs_human("Confirm frame form: #{result['frame_form']}. #{note}",
                    { result: result, note: note, recommended_action: "confirm" })
      end
    end
  end
end
```

### 6.6 A5 — Lock the style-level entry

```ruby
# app/steps/track_a/lock_style_entry.rb
module Steps
  module TrackA
    class LockStyleEntry < Steps::Base
      step id: "A5", mechanism: :human, ownership: "[HUMAN ONLY]"

      # context: { style_slug:, style_name:, mood:, content_type:, frame_form:, confirmed: }
      def perform
        unless context[:confirmed]
          return needs_human(
            "Lock these three values as final for this style?\n" \
            "  mood:         #{context[:mood]}\n" \
            "  content_type: #{context[:content_type]}\n" \
            "  frame_form:   #{context[:frame_form]}\n\n" \
            "Validation: could someone unfamiliar with the style read these three values alone " \
            "and generate a reasonably on-style prompt? If not, they are too vague — return to A1 " \
            "and narrow the reference set.",
            context.slice(:mood, :content_type, :frame_form)
          )
        end

        spec = KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
          slug:         context.fetch(:style_slug),
          name:         context.fetch(:style_name),
          mood:         context.fetch(:mood),
          content_type: context.fetch(:content_type),
          frame_form:   context.fetch(:frame_form)
        )

        ok({ style_spec_path: spec.path.to_s, slug: spec.slug },
           message: "Style-level axes locked. COMMIT knowledge_base/style_specs/#{spec.slug}.yml " \
                    "to git before running any pipeline against it.")
      end
    end
  end
end
```

**Grounding:** *This Is Marketing* — "specific is brave". Vague axis values produce generic output,
which defeats the niche's whole premise.

> **Important:** A5 writes a file, not a database row. The orchestrator must surface the reminder to
> commit it — `Workflow::PreflightCheck` will refuse to run a production pipeline until it is
> committed.

---

## 7. Track A run order

```
A0 (research + human go/no-go)
   ↓ go
A1 (assemble reference set + human curates)
   ↓
A2 (mood)  ──── mixed/weak? ──→ back to A1
   ↓ confirmed
A3 (content type) ── contour mismatch? ──→ reconsider
   ↓ confirmed
A4 (frame form, uses confirmed mood as tiebreaker)
   ↓ confirmed
A5 (human locks → writes style_specs/<slug>.yml → COMMIT)
   ↓
Track B (module 02) fills in the per-scene axes
```

A4 depends on A2's confirmed mood. A2 and A3 both depend on A1's curated set. Do not parallelise A4
ahead of A2.

---

## 8. Verification for this module

```bash
# Rule files exist and carry citations
bin/rails runner '
  %w[reference_set_criteria mood_markers content_type frame_form].each do |n|
    r = KnowledgeBase::RuleSet.load(n)
    puts "#{n}: source=#{r.meta["source"].present?} citation=#{r.meta["citation"].present?}"
  end
'

# Mood markers: exactly 4, each with both columns and a citation
bin/rails runner '
  m = KnowledgeBase::RuleSet.load("mood_markers").rules["markers"]
  puts "markers=#{m.size}"                                            # expect 4
  puts "complete=#{m.all? { |x| x["calm_ordered"] && x["bold_active"] && x["citation"] }}"
'

# Reference criteria: 4 search steps, 4 image requirements
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("reference_set_criteria").rules
  puts "search_steps=#{r["search_process"].size} requirements=#{r["image_requirements"].size}"
'                                                                     # expect 4 and 4

# All 5 prompts render without missing interpolations
bin/rails runner '
  puts format(Pipeline::KB_ROOT.join("prompts/a0_style_validation.md").read, style_name: "Japandi").size
  puts format(Pipeline::KB_ROOT.join("prompts/a1_reference_set.md").read, style_name: "Japandi").size
  puts Pipeline::KB_ROOT.join("prompts/a2_mood.md").read.size
  puts Pipeline::KB_ROOT.join("prompts/a3_content_type.md").read.size
  puts format(Pipeline::KB_ROOT.join("prompts/a4_frame_form.md").read, mood: "calm_ordered").size
'

# Step classes match the registry
bin/rails runner '
  reg = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  reg["phase_1"]["track_a"]["steps"].each do |s|
    k = s["klass"].constantize
    ok = k.step_id == s["id"] && k.ownership == s["ownership"]
    puts "#{s["id"]}: #{ok ? "ok" : "MISMATCH"}"
  end
'

# Writer round-trips and validates
bin/rails runner '
  KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
    slug: "test-style", name: "Test", mood: "calm_ordered",
    content_type: "minimalist_modern", frame_form: "angular")
  s = KnowledgeBase::StyleSpec.load("test-style")
  puts s.style_level.inspect
  begin
    KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
      slug: "test-bad", name: "Bad", mood: "nonsense",
      content_type: "minimalist_modern", frame_form: "angular")
    puts "FAIL — should have raised"
  rescue KnowledgeBase::IncompleteSpecError
    puts "rejects bad values ok"
  end
'
rm knowledge_base/style_specs/test-style.yml knowledge_base/style_specs/test-bad.yml 2>/dev/null

# A0 and A1 use the verified search runner, not the earlier-guessed native tool
bin/rails runner '
  src_a0 = Steps::TrackA::ValidateStyle.instance_method(:perform).source_location
  body = File.read(src_a0.first)
  puts body.include?("Search::ReasonedRunner") ? "A0 uses ReasonedRunner: ok" : "A0 MISSING ReasonedRunner"
  puts body.include?("RubyLLM::Tools::WebSearch") ? "A0 STILL references the nonexistent tool — fix" : "A0 clean"
'
```

**Also verify by hand:**
- `a0_style_validation.md` matches the source research template word for word, including all five
  numbered methodology points.
- A2 returns `needs_human` with `recommended_action: "return_to_a1"` when the model reports `mixed` —
  it must never silently pick a mood.
- A5 does not write the file until `context[:confirmed]` is true.
- A0 and A1 both raise/handle `Search::NoSearchPerformedError` — module 00b must be built before this
  module can actually run, even though module 00b is documented as an addendum rather than a
  numbered dependency.

---

## 9. Manifest coverage

| ID | Item | Where |
|---|---|---|
| A0–A5 | All 6 Track A steps with verbatim ownership tags | §6 |
| P1-P1 | Reusable research template, 5 methodology points, verbatim | §3.1 |
| P1-P2 | A1 search process, 4 numbered steps incl. 3-4 per-source cap | §2.1, §3.2 |
| P1-T3 | Valid reference image requirements (4 rows) | §2.1 `image_requirements` |
| P1-T4 | Four mood markers, calm vs. bold columns (4 rows) | §2.2 `markers` |
| — | A2 mixed-scorecard → return to A1 rule | §2.2, enforced in §6.3 |
| — | A3 contour cross-check validation | §2.3, enforced in §6.4 |
| — | A4 mood tiebreaker for mixed framing | §2.4, enforced in §6.5 |
| — | A0 grounding (*This Is Marketing* Ch. 4 & 8; *Paradox of Choice*) | §6.1 |
| — | A5 grounding (*This Is Marketing*, "specific is brave") | §6.6 |
| — | A1 explicitly flagged unsourced | §2.1 `meta.citation` |

**Deferred to other modules:** the OCR caveat on p. 56 lives in module 00's
`knowledge_base/README.md` (§4.4) and is repeated as `meta.provenance_warning` in §2.2 here. The
authoritative frame-contour rule is module 04's, not §2.3's cross-check copy.

**Corrected after initial drafting:** A0 and A1 originally assumed a built-in
`RubyLLM::Tools::WebSearch` tool. That tool doesn't exist. Both steps now use
`Search::ReasonedRunner` (module 00b) — see §6.1 and §6.2, and 00b for the underlying
implementation. A1's rule-file citation was also corrected: it isn't "unsourced" — it's not
grounded in the book corpus, but its own output is held to a 2-independent-source-per-image bar,
stricter than most rules in this project. See §2.1.
