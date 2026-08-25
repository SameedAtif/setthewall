# Module 02 — Phase 1, Track B: Per-Scene Axes

> **Self-contained.** Every rule, prompt, criterion, and borderline-default rule this module needs is
> written out below verbatim. Do not search the internet for the domain content — it is all here.
> Build exactly what is specified.

---

## Contract

**Depends on:** module 00 (`Steps::Base`, `KnowledgeBase::StyleSpec`, `KnowledgeBase::SceneSpec`,
`KnowledgeBase::RuleSet`, `Pipeline::KB_ROOT`, `config/step_registry.yml`) and module 01
(`KnowledgeBase::StyleSpecWriter` — Track B **extends** an existing style-level spec file with scene
data; it must not exist before A5 has locked the style-level entry).

**Provides:**
- `knowledge_base/rules/borderline_defaults.yml` — the four B1/B2/B3/B4 borderline rules, with B3
  deliberately marked as having no safe default
- `knowledge_base/rules/color_role_observation.yml` — B6 step-1 observation table
- `knowledge_base/prompts/b1_wall_condition.md` through `b6_color_role.md`
- `app/steps/track_b/*.rb` — 8 step classes (B0–B7)
- `app/llm/schemas/track_b/*.rb`
- `KnowledgeBase::SceneSpecWriter` — the only code permitted to write scene keys into
  `style_specs/*.yml`
- `knowledge_base/scene_templates/` file format definition (the physical/measurement metadata Phase 2
  Step 6 will actually use — this module defines the format; module 04 uses it)

**Consumed by:** module 03 (Track C reads scene axes for space-tip constraints on generation),
module 04 (Phase 2 reads every axis to look up rules), module 07 (evolution loop reads scene data).

**Must not:** touch `style_level` keys in the spec (module 01 owns those), reference or duplicate
Phase 2 rule tables (module 04 owns those; Track B *classifies*, Phase 2 *acts on* the classification),
call the Phase 2 `frame_material.yml` / `eye_level.yml` etc. even in a cross-check — those files
don't exist yet at Track B time.

---

## 1. What Track B is

Track B determines the **six per-scene axes** — Wall Condition, Furniture Weight, Room Type, Room
Shape/Proportion, Space Math, Color Role — that are set **once per scene template** and reused for
every piece placed in that template. A style typically has 3 scene templates (per Phase 2's guidance);
Track B runs once per template, then never again for that template.

Cadence: `per_scene`. Track B does not run daily.

**Track B's key design property, verbatim from the source doc:** B1–B5 are observation + rule lookup;
B6 has one genuinely strategic sub-step that requires human judgment (the Content Type override). The
borderline-default rules on B1/B2/B3/B4 are the whole reason those steps are safe to give to a vision
model at all — without them, an ambiguous read has no defined behaviour and the pipeline breaks
silently downstream.

---

## 2. Rule files to create

### 2.1 `knowledge_base/rules/borderline_defaults.yml`

This file exists specifically because vision models will hit ambiguous scenes and, without an
explicit "if genuinely borderline, do X" rule, will pick arbitrarily. The source doc writes these
into each B-step; this file makes them one machine-readable rule an orchestrator can also enforce.

```yaml
meta:
  source: "Phase 1, Track B — borderline-default rules on B1, B2, B3, B4"
  citation: >
    how_to_arrange_pictures / at_home_with_pictures — B1 references p. 61 (the "read
    distinctly against this wall" test); B2/B3/B4 defaults reflect the safe-fail direction
    for the downstream rule each axis feeds (§2.3, §2.9, §2.10, §2.5a in module 04).
  volatility: static
  design_note: >
    Every borderline-default here is the direction that produces the LESS damaging error if
    wrong. B3 is deliberately the one axis with NO safe default — the eye-level formulas it
    picks between are not interchangeable, so a wrong guess silently breaks Step 6's
    compositing math. That step must escalate to a human, not default.

rules:
  wall_condition:
    axis: wall_condition
    on_ambiguous: neutral
    reasoning: >
      The match-vs-contrast rule this axis feeds (module 04 §2.3) is more forgiving of a
      false "neutral" than a false "busy". A subtle texture or low-contrast pattern
      classified as neutral will still produce a workable frame decision.
    escalate: false

  furniture_weight:
    axis: furniture_weight
    on_ambiguous: light
    reasoning: >
      Weight-balance check (module 04 §2.9): art lighter than dark furniture is required;
      art heavier than light furniture is only "allowed", not required. Defaulting to light
      furniture treats the check as advisory rather than mandatory in the ambiguous case,
      which fails less loudly.
    escalate: false

  room_type:
    axis: room_type
    on_ambiguous: null
    reasoning: >
      NO SAFE DEFAULT. Each value picks a different eye-level formula (module 04 §2.10):
      seated_room uses "5-6 inches above the back of the couch/chairs", hallway uses "at
      or just above eye level", no_furniture_wall has neither reference point. A wrong
      classification silently produces wrong eye-level math in Phase 2 Step 6, which will
      not fail loudly — it will produce a plausible-looking but wrong composite.
    escalate: true
    escalation_reason: "eye-level formulas are not interchangeable"

  room_shape:
    axis: room_shape
    on_ambiguous: none
    reasoning: >
      Room shape only adds an OPTIONAL generation constraint in Track C (space tips —
      module 04 §2.5a). A false negative ("none") just skips an optional space-tip; a
      false positive forces an unnecessary constraint on generation. "None of these" is
      explicitly named in the source doc as a legitimate, common answer.
    escalate: false
```

### 2.2 `knowledge_base/rules/color_role_observation.yml`

The four-row observation table from B6 step 1 — matching the scene's existing color state to a
candidate role. B6 step 2 (Content Type override, human-decided) and step 3 (B1/B2 cross-check) are
enforced in the step class itself, not in this rule file.

```yaml
meta:
  source: "Phase 1, Step B6 — Color Role, step 1"
  citation: "how_to_arrange_pictures / at_home_with_pictures — p. 82 (accent-highlighter), p. 84 (unifier), p. 91 (color-burst, saturator), p. 97 (line-only default)"
  volatility: static
  note: >
    This is only step 1 of B6 (observation → candidate role). Step 2 (Content Type override
    to line_only for minimalist_modern) is a human-decided call implemented in the B6 step
    class. Step 3 (cross-check against B1/B2) is a validation implemented in the same class.
    The full B6 logic lives across all three, not in this file alone.

rules:
  axis: color_role
  values: [accent_highlighter, color_burst, unifier, saturator, line_only]

  observation:
    - observation: "Predominantly neutral/muted, no strong existing color anywhere"
      candidate_role: color_burst
      citation: "p. 91"
      role_description: >
        The piece becomes the room's one saturated note. A saturated piece "stimulates"
        a whole muted room, making its understated colors feel more alive by contrast.
    - observation: "One existing accent color present but understated, easy to miss"
      candidate_role: accent_highlighter
      citation: "p. 82"
      role_description: "Brings out an accent color already in the room that would otherwise fade."
    - observation: "Multiple scattered color touches (pillows, throw, small objects) not yet visually tied together"
      candidate_role: unifier
      citation: "p. 84"
      role_description: "Ties together touches of color already scattered through the room."
    - observation: "A clear dominant color theme already established throughout"
      candidate_role: saturator
      citation: "p. 91"
      role_description: "Repeats and reinforces the room's existing dominant color theme."

  # Not in the observation table — invoked only by step 2 (Content Type override)
  minimalist_modern_default:
    candidate_role: line_only
    citation: "p. 97"
    role_description: >
      Removes color tension entirely so line, pattern, and light/dark contrast carry the
      piece. Black/white/gray display, minimal or no color in mat/frame — "allows the
      lines to sing." This is the default color role for a minimalist/Japandi-type spec.
    override_rule: >
      If content_type is minimalist_modern, this default OVERRIDES the observation-table
      result from step 1 UNLESS the human has a specific catalog-strategy reason to make
      this particular scene a deliberate color statement within an otherwise monochrome
      catalog. The override is the one genuinely strategic call in B6 and cannot be made
      by the agent.
```

### 2.3 `knowledge_base/scene_templates/` — file format

Track B doesn't populate the physical measurements here (that's a setup step for the human who
builds the mockup templates). But this module *defines the format*, because Track B needs to reference
templates by ID and Phase 2 Step 6 will read from them.

Create `knowledge_base/scene_templates/README.md` with this content:

```markdown
# Scene Templates

Each scene template is a mockup image + calibrated measurements. Track B (module 02) classifies each
template on the six per-scene axes. Phase 2 Step 6 (module 04) uses the measurements to place art at
correct eye level, spacing, and coverage.

## File format

One YAML per template: `knowledge_base/scene_templates/<template_id>.yml`

```yaml
id: behind_sofa_light_neutral
name: "Behind sofa — light neutral"
image_path: "scene_templates/assets/behind_sofa_light_neutral.png"

# Physical measurements in the scene image, in pixels.
# These are populated by the human who builds the template, before Track B runs.
# Track B does NOT infer or measure these — it classifies the scene's axis values only.
measurements:
  image_width_px: 2400
  image_height_px: 1600
  # Pixels per inch, calibrated against a known-size object in the scene.
  # Required for Phase 2 Step 6 to translate the book's inch-based rules into pixel math.
  pixels_per_inch: 24

  # Anchor rectangles used by Step 6. Only include the ones relevant to this scene type.
  furniture_top_edge_y_px: 900      # top of the sofa/table/etc. — for the 8-10" gap rule
  wall_zone: { x: 200, y: 100, width: 2000, height: 800 }   # placement region
  seated_eye_level_y_px: 850        # only for room_type: seated_room
  standing_eye_level_y_px: 720      # only for room_type: hallway or no_furniture_wall

  # Furniture width in pixels — for the 2/3-3/4 fill rule and the group-width rule.
  furniture_width_px: 1600
```

## What Track B does with these

Track B loads each template's image, classifies the six axes against it, and writes the classification
back into `style_specs/<style>.yml` under `scenes.<template_id>.axes`. Measurements are read but not
modified. Track B never edits a scene_template file.
```

Also create `knowledge_base/scene_templates/assets/.keep` so the assets directory exists.

---

## 3. Prompt files to create

Each prompt is scoped tightly to its one classification task — the borderline-default rule is
included in the prompt itself so the model reasons over it, *and* enforced separately in the step
class so the rule is applied even if the model ignores it.

### 3.1 `knowledge_base/prompts/b1_wall_condition.md`

```markdown
Classify this scene's wall as neutral/plain or busy/patterned.

Apply this specific test: would a frame need to "read distinctly" against this wall to avoid
disappearing? If yes, the wall is busy/patterned. If a frame in almost any material would sit clearly
against the wall, the wall is neutral/plain.

If the wall is genuinely borderline — a subtle texture, a very low-contrast pattern, or a colour close
to what a common frame would be — classify as neutral/plain. This is the safe-fail direction: the
match-vs-contrast rule this axis feeds is more forgiving of a false "neutral" than a false "busy".

Report `borderline: true` whenever you invoke this fallback, so the pipeline knows the classification
was ambiguous. Return JSON matching the required schema.
```

### 3.2 `knowledge_base/prompts/b2_furniture_weight.md`

```markdown
Classify the visible furniture in this scene as light or dark.

Weight is driven by colour AND size together, not colour alone. A large pale wooden table can carry
more visual weight than a small dark stool — read both signals before deciding.

If the furniture is a mid-tone or the read is genuinely ambiguous, classify as light. This is the
safe-fail direction: the weight-balance rule this axis feeds requires art lighter than dark
furniture, but only allows (does not require) art heavier than light furniture — defaulting to light
turns the check into a permission rather than a mandate in the ambiguous case.

Report `borderline: true` whenever you invoke this fallback. Return JSON matching the required schema.
```

### 3.3 `knowledge_base/prompts/b3_room_type.md`

```markdown
Classify the room in this scene as one of:

- **seated_room** — a living or dining room with couches/chairs where people sit at length.
- **hallway** — a passageway or corridor, no seated furniture.
- **no_furniture_wall** — a wall with no furniture directly beneath it (entry wall, stairwell wall,
  a bare wall in any room).

If the scene is genuinely ambiguous — for example, a hallway with a bench, or a seated space with
minimal furniture off to one side — do NOT guess. Report the classification as `ambiguous` and
explain what makes it ambiguous.

This is the ONE per-scene axis with no safe default: the three eye-level formulas that follow are not
interchangeable (a wrong guess silently produces wrong eye-level math downstream). The correct
behaviour on ambiguity is to escalate to a human, not to pick.

Return JSON matching the required schema.
```

### 3.4 `knowledge_base/prompts/b4_room_shape.md`

```markdown
Classify the room shape/proportion in this scene as one of:

- **narrow** — a room significantly deeper than it is wide.
- **low_ceilinged** — a room whose ceiling reads as low relative to its floor area.
- **small_closed_in** — a small room that feels enclosed or cramped.
- **none** — none of the above conditions apply.

"None" is a legitimate, common answer — do not force a fit. Most standard rooms are "none". This axis
only adds an optional space-tip constraint on art generation; a false positive forces an unnecessary
constraint, while "none" simply skips it.

If the read is genuinely borderline between a category and "none", classify as `none`. This is the
safe-fail direction.

Report `borderline: true` whenever you invoke this fallback. Return JSON matching the required schema.
```

### 3.5 `knowledge_base/prompts/b5_space_math.md`

```markdown
Measure the wall region this scene will use for placement. Classify the space math as one of:

- **single** — furniture-anchored, and one piece at 2/3-3/4 of the furniture's width fills the space
  well.
- **set** — furniture-anchored, but a single piece does not fill the space, OR the furniture beneath
  is minimal so a set is more appropriate.
- **split_wall** — wide-open wall with no furniture to anchor against (e.g. a hallway).
- **nook** — an architectural nook (window surround, chimney jog, built-in, or other wall quirk) that
  wants a piece shaped to it rather than a standard wall run.
- **surface** — a horizontal surface (mantel, shelf, console, windowsill), not a wall mount at all.

This is arithmetic against the actual scene dimensions, not preference. If you have the scene image
and can identify a rough furniture width or wall region, use those numbers to justify the call. If a
piece at 2/3-3/4 of furniture width would visibly fill the space, that is `single`; if it would leave
significant empty wall on either side, that is `set` (or `split_wall` if the wall is furniture-less
entirely).

Return JSON matching the required schema, including your reasoning about proportions.
```

### 3.6 `knowledge_base/prompts/b6_color_role.md`

```markdown
Observe this scene's existing colour state (step 1 of 3 for this axis).

Match to the closest description:

- **Predominantly neutral/muted, no strong existing colour anywhere** → candidate role: `color_burst`
  (the piece becomes the room's one saturated note).
- **One existing accent colour present but understated, easy to miss** → candidate role:
  `accent_highlighter` (brings out the accent).
- **Multiple scattered colour touches not yet visually tied together** → candidate role: `unifier`
  (ties them together).
- **A clear dominant colour theme already established** → candidate role: `saturator` (reinforces it).

Report your candidate role and describe the specific colour state you observed. Do NOT apply the
Content Type override (step 2) — that is a strategic human call and is handled outside your response.
Do NOT apply the B1/B2 cross-check (step 3) — that is handled in code.

Return JSON matching the required schema.
```

---

## 4. Schema classes

Every classification schema carries a `borderline` boolean so the step class can enforce the
borderline-default rule programmatically instead of trusting the model to have done it.

```ruby
# app/llm/schemas/track_b/wall_condition_schema.rb
module Schemas
  module TrackB
    class WallConditionSchema < RubyLLM::Schema
      string :wall_condition, enum: %w[neutral busy]
      boolean :borderline, description: "True if the safe-fail default was invoked"
      string :reasoning
    end
  end
end
```

```ruby
# app/llm/schemas/track_b/furniture_weight_schema.rb
module Schemas
  module TrackB
    class FurnitureWeightSchema < RubyLLM::Schema
      string :furniture_weight, enum: %w[light dark]
      boolean :borderline
      string :reasoning
    end
  end
end
```

```ruby
# app/llm/schemas/track_b/room_type_schema.rb
module Schemas
  module TrackB
    class RoomTypeSchema < RubyLLM::Schema
      string :room_type,
             enum: %w[seated_room hallway no_furniture_wall ambiguous],
             description: "'ambiguous' triggers a human-required escalation — there is no safe default here"
      string :reasoning
      string :ambiguity_reason, required: false,
             description: "Required if room_type is 'ambiguous'"
    end
  end
end
```

```ruby
# app/llm/schemas/track_b/room_shape_schema.rb
module Schemas
  module TrackB
    class RoomShapeSchema < RubyLLM::Schema
      string :room_shape, enum: %w[narrow low_ceilinged small_closed_in none]
      boolean :borderline
      string :reasoning
    end
  end
end
```

```ruby
# app/llm/schemas/track_b/space_math_schema.rb
module Schemas
  module TrackB
    class SpaceMathSchema < RubyLLM::Schema
      string :space_math, enum: %w[single set split_wall nook surface]
      string :reasoning,
             description: "Include the proportions you used to arrive at this classification"
    end
  end
end
```

```ruby
# app/llm/schemas/track_b/color_role_schema.rb
module Schemas
  module TrackB
    # Only covers step 1 of B6. Steps 2 and 3 are decided outside the LLM call.
    class ColorRoleObservationSchema < RubyLLM::Schema
      string :candidate_role,
             enum: %w[color_burst accent_highlighter unifier saturator]
      string :observed_color_state,
             description: "The specific colour state observed — used later for the B1/B2 cross-check"
      string :reasoning
    end
  end
end
```

---

## 5. `KnowledgeBase::SceneSpecWriter`

Parallel to module 01's `StyleSpecWriter` — writes scene keys, must not touch `style_level`.

```ruby
# app/knowledge_base/scene_spec_writer.rb
module KnowledgeBase
  class SceneSpecWriter
    # Overwrites the axes for one scene under an existing style spec.
    # Refuses to run if style_level hasn't been locked yet (A5 must complete first).
    def self.write_scene_axes(style_slug:, scene_id:, scene_name:, template_ref:, axes:)
      path = Pipeline::KB_ROOT.join("style_specs", "#{style_slug}.yml")
      unless path.exist?
        raise IncompleteSpecError,
              "Style spec '#{style_slug}' not found. Run Track A (module 01) first."
      end

      doc = YAML.safe_load_file(path, permitted_classes: [Date])
      if doc["style_level"].blank?
        raise IncompleteSpecError,
              "Style spec '#{style_slug}' has no style_level. Track A A5 must run before Track B."
      end

      validate_axes!(axes)

      doc["scenes"] ||= {}
      doc["scenes"][scene_id.to_s] = {
        "name"         => scene_name,
        "template_ref" => template_ref,
        "locked_at"    => Date.current.to_s,
        "axes"         => axes.transform_keys(&:to_s).transform_values(&:to_s)
      }

      path.write(<<~HEADER + doc.to_yaml.sub(/\A---\n/, ""))
        # Style Spec — style-level axes set by Track A (module 01),
        # scene axes appended by Track B (module 02).
        ---
      HEADER

      StyleSpec.load(style_slug).scene(scene_id.to_s)
    end

    def self.validate_axes!(axes)
      StyleSpec::SCENE_AXES.each do |axis|
        value = axes[axis] || axes[axis.to_s]
        allowed = StyleSpec::ALLOWED[axis]
        if value.blank?
          raise IncompleteSpecError, "axes.#{axis} is blank — every scene axis must have a value"
        end
        unless allowed.include?(value.to_s)
          raise IncompleteSpecError, "axes.#{axis}='#{value}' not in #{allowed}"
        end
      end
    end
  end
end
```

---

## 6. Step implementations

All eight Track B steps operate on **a scene template**, not a `PieceRecord`. Pass `piece: nil` and
put the scene context in `context`:

```ruby
context: {
  style_slug: "japandi-v1",
  scene_template_id: "behind_sofa_light_neutral",
  scene_image: "knowledge_base/scene_templates/assets/behind_sofa_light_neutral.png",
  # ...for B4 only: any human note about intended usage
  # ...for B6 step 2 only: content_type + human's override decision
}
```

### 6.1 B0 — Confirm the scene template is fixed

```ruby
# app/steps/track_b/confirm_scene_template.rb
module Steps
  module TrackB
    class ConfirmSceneTemplate < Steps::Base
      step id: "B0", mechanism: :human, ownership: "[HUMAN ONLY]"

      def perform
        template_path = Pipeline::KB_ROOT.join(context.fetch(:scene_image))
        template_yml  = Pipeline::KB_ROOT.join("scene_templates",
                                               "#{context.fetch(:scene_template_id)}.yml")

        missing = []
        missing << "image asset (#{template_path})" unless template_path.exist?
        missing << "template metadata (#{template_yml})" unless template_yml.exist?

        if missing.any?
          return fail_step(
            "Scene template is not fully set up. Missing: #{missing.join(', ')}. Track B cannot " \
            "run against a template that hasn't been built and calibrated first — see " \
            "scene_templates/README.md.",
            { missing: missing }
          )
        end

        needs_human(
          "Confirm this scene template is a REUSABLE mockup you will use across many pieces — " \
          "not a one-off generated room. Validation: template files exist and are versioned; the " \
          "measurement metadata (pixels_per_inch, furniture edges, etc.) is filled in.",
          { template_id: context.fetch(:scene_template_id) }
        )
      end
    end
  end
end
```

**Grounding:** Phase 2's own 3-templates-per-space guidance — Track B is only worth running against a
template that will be reused, not against a fresh generation per piece.

### 6.2 B1 — Wall Condition

```ruby
# app/steps/track_b/wall_condition.rb
module Steps
  module TrackB
    class WallCondition < Steps::Base
      step id: "B1", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::WallConditionSchema)
                        .ask(prompt("b1_wall_condition"), with: context.fetch(:scene_image))
                        .content

        apply_borderline_default!(result, :wall_condition)

        ok({ wall_condition: result["wall_condition"], borderline: result["borderline"],
             reasoning: result["reasoning"] })
      end

      private

      # Even if the prompt tells the model what to do when borderline, we re-apply the rule in
      # code as a belt-and-braces guarantee — the borderline_defaults.yml file is the source of
      # truth for this behaviour, not the model.
      def apply_borderline_default!(result, axis_key)
        return unless result["borderline"]

        default = rules("borderline_defaults").fetch(axis_key.to_s, "on_ambiguous")
        return if default.nil?    # would only be true for B3, which doesn't call this method

        result[axis_key.to_s] = default
      end
    end
  end
end
```

### 6.3 B2 — Furniture Weight

```ruby
# app/steps/track_b/furniture_weight.rb
module Steps
  module TrackB
    class FurnitureWeight < Steps::Base
      step id: "B2", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::FurnitureWeightSchema)
                        .ask(prompt("b2_furniture_weight"), with: context.fetch(:scene_image))
                        .content

        if result["borderline"]
          result["furniture_weight"] = rules("borderline_defaults")
                                       .fetch("furniture_weight", "on_ambiguous")
        end

        ok({ furniture_weight: result["furniture_weight"], borderline: result["borderline"],
             reasoning: result["reasoning"] })
      end
    end
  end
end
```

### 6.4 B3 — Room Type (the deliberate no-safe-default case)

```ruby
# app/steps/track_b/room_type.rb
module Steps
  module TrackB
    class RoomType < Steps::Base
      step id: "B3", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::RoomTypeSchema)
                        .ask(prompt("b3_room_type"), with: context.fetch(:scene_image))
                        .content

        if result["room_type"] == "ambiguous"
          # This is enforced from the rule file explicitly — the escalate flag is the machine-
          # readable signal that B3 has no safe default and MUST NOT fall back to guessing.
          rule = rules("borderline_defaults").fetch("room_type")
          return needs_human(
            "B3 came back ambiguous (#{result['ambiguity_reason']}). Per " \
            "borderline_defaults.yml, this axis has no safe default: #{rule['reasoning']} " \
            "Classify the room type as seated_room, hallway, or no_furniture_wall.",
            { llm_result: result, escalation_reason: rule["escalation_reason"] }
          )
        end

        ok({ room_type: result["room_type"], reasoning: result["reasoning"] })
      end
    end
  end
end
```

**Why this is a hard `needs_human` and not a borderline-default fallback:** the source doc is explicit
that the three eye-level formulas are not interchangeable, and a wrong classification here produces a
plausible-looking but wrong composite downstream in Phase 2 Step 6. The point of automating this
pipeline is to catch that at the classification step, not after publishing.

### 6.5 B4 — Room Shape/Proportion

```ruby
# app/steps/track_b/room_shape.rb
module Steps
  module TrackB
    class RoomShape < Steps::Base
      step id: "B4", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::RoomShapeSchema)
                        .ask(prompt("b4_room_shape"), with: context.fetch(:scene_image))
                        .content

        if result["borderline"]
          result["room_shape"] = rules("borderline_defaults").fetch("room_shape", "on_ambiguous")
        end

        ok({ room_shape: result["room_shape"], borderline: result["borderline"],
             reasoning: result["reasoning"] })
      end
    end
  end
end
```

### 6.6 B5 — Space Math

```ruby
# app/steps/track_b/space_math.rb
module Steps
  module TrackB
    class SpaceMath < Steps::Base
      step id: "B5", mechanism: :llm_vision, ownership: "[AGENT-READY]"

      def perform
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::TrackB::SpaceMathSchema)
                        .ask(prompt("b5_space_math"), with: context.fetch(:scene_image))
                        .content

        ok({ space_math: result["space_math"], reasoning: result["reasoning"] })
      end
    end
  end
end
```

**Note:** B5 has no borderline-default because it's explicitly arithmetic in the source doc —
"measure before deciding". Ambiguity here is a signal the *template* hasn't been calibrated
properly, not that the classifier needs a fallback. If B5's reasoning shows the model guessing about
proportions rather than measuring, the fix is a better template setup (§2.3's `measurements` block),
not a default value.

### 6.7 B6 — Color Role (three substeps)

```ruby
# app/steps/track_b/color_role.rb
module Steps
  module TrackB
    class ColorRole < Steps::Base
      step id: "B6",
           mechanism: :llm_vision,
           ownership: "[AGENT-READY for steps 1 & 3 — human confirms the override call in step 2]"

      # context additions expected:
      #   content_type:            the style's content_type (from Track A / style spec)
      #   wall_condition:          B1's confirmed value
      #   furniture_weight:        B2's confirmed value
      #   catalog_strategy_override: nil, or a human-supplied reason to override the
      #                              minimalist_modern → line_only default in step 2
      def perform
        # === Step 1 — observation ===
        step1 = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                      .with_schema(Schemas::TrackB::ColorRoleObservationSchema)
                      .ask(prompt("b6_color_role"), with: context.fetch(:scene_image))
                      .content

        candidate = step1["candidate_role"]

        # === Step 2 — Content Type override (human-decided) ===
        # Rule from color_role_observation.yml: if content_type is minimalist_modern, line_only
        # OVERRIDES the observation candidate UNLESS the human has a specific catalog-strategy
        # reason to keep the observation-driven role. This is the one non-mechanical call in B6.
        content_type   = context.fetch(:content_type)
        override_role  = nil
        override_reason = nil

        if content_type == "minimalist_modern"
          if context[:catalog_strategy_override].present?
            override_reason = "human catalog-strategy override: #{context[:catalog_strategy_override]}"
          elsif candidate != "line_only"
            # The default fires — but this is exactly where the human confirms, per ownership tag.
            return needs_human(
              "B6 Content Type override: content_type is minimalist_modern, so the documented " \
              "default (line_only, p.97) OVERRIDES the observation-driven candidate " \
              "(#{candidate}). Confirm the override, OR provide a catalog-strategy reason to " \
              "keep #{candidate} instead. This is the one strategic call in B6 that cannot be " \
              "made by the agent.",
              { observation_candidate: candidate,
                default_override: "line_only",
                override_citation: "p. 97, module 04 §2.2a" }
            )
          end
        end

        chosen_role = override_role || candidate

        # === Step 3 — cross-check against B1/B2 ===
        conflicts = cross_check(chosen_role, context.fetch(:wall_condition),
                                context.fetch(:furniture_weight))

        if conflicts.any?
          return needs_human(
            "B6 step-3 cross-check flagged conflicts: #{conflicts.join('; ')}. Per the source " \
            "rule, resolve the conflict explicitly rather than defaulting to whichever was " \
            "decided first.",
            { chosen_role: chosen_role, conflicts: conflicts }
          )
        end

        ok({ color_role: chosen_role, candidate_role: candidate,
             override_reason: override_reason,
             observed_color_state: step1["observed_color_state"] })
      end

      private

      def cross_check(role, wall_condition, furniture_weight)
        conflicts = []
        # Color-burst assumes a neutral backdrop — a busy wall contradicts that
        if role == "color_burst" && wall_condition == "busy"
          conflicts << "color_burst assumes a neutral backdrop, but wall_condition is busy"
        end
        # Unifier assumes visible scattered accents — flag against very-plain scenes
        # (heuristic: busy wall + light furniture is a common no-accent combination)
        if role == "unifier" && wall_condition == "neutral" && furniture_weight == "light"
          conflicts << "unifier assumes visible scattered accents, but this scene reads as " \
                       "very plain (neutral wall + light furniture)"
        end
        conflicts
      end
    end
  end
end
```

**Note on step 2 vs. the human-gate flow:** the ownership tag says "human confirms the override call
in step 2" — so this step returns `needs_human` at the override point rather than silently applying
`line_only`. The human's confirmation (via module 06's review UI) sets `catalog_strategy_override`
in `context` on re-invocation, either as `nil` (accept the `line_only` default) or as a specific
strategic reason (keep the observation-driven candidate).

### 6.8 B7 — Lock the per-scene entry

```ruby
# app/steps/track_b/lock_scene_entry.rb
module Steps
  module TrackB
    class LockSceneEntry < Steps::Base
      step id: "B7", mechanism: :human, ownership: "[HUMAN ONLY]"

      # context: { style_slug:, scene_template_id:, scene_name:, template_ref:,
      #            axes: { wall_condition:, furniture_weight:, room_type:, room_shape:,
      #                    space_math:, color_role: },
      #            confirmed: }
      def perform
        axes = context.fetch(:axes)

        unless context[:confirmed]
          return needs_human(
            "Lock these six values as final for this scene template?\n" \
            "  wall_condition:   #{axes[:wall_condition]}\n" \
            "  furniture_weight: #{axes[:furniture_weight]}\n" \
            "  room_type:        #{axes[:room_type]}\n" \
            "  room_shape:       #{axes[:room_shape]}\n" \
            "  space_math:       #{axes[:space_math]}\n" \
            "  color_role:       #{axes[:color_role]}\n\n" \
            "Validation (from the source doc): could someone who has never seen the scene photo " \
            "make correct placement/frame decisions from these six values alone? If not, a value " \
            "is under-specified — go back and sharpen it.",
            { axes: axes }
          )
        end

        scene = KnowledgeBase::SceneSpecWriter.write_scene_axes(
          style_slug:      context.fetch(:style_slug),
          scene_id:        context.fetch(:scene_template_id),
          scene_name:      context.fetch(:scene_name),
          template_ref:    context.fetch(:template_ref),
          axes:            axes
        )

        ok({ style_slug: context.fetch(:style_slug), scene_id: scene.id },
           message: "Scene axes locked. COMMIT knowledge_base/style_specs/" \
                    "#{context.fetch(:style_slug)}.yml to git before running any daily pipeline " \
                    "against it.")
      end
    end
  end
end
```

---

## 7. Track B run order

```
[Track A must be complete — A5 has written style_level to style_specs/<slug>.yml]

B0 (confirm template is fixed — human)
  ↓
B1 (wall condition) ─── ambiguous? → default to neutral
  ↓
B2 (furniture weight) ─ ambiguous? → default to light
  ↓
B3 (room type) ──────── ambiguous? → HUMAN REQUIRED (no safe default)
  ↓
B4 (room shape) ─────── ambiguous? → default to "none"
  ↓
B5 (space math) ─────── arithmetic, no default
  ↓
B6 (color role):
    step 1: observation → candidate role
    step 2: Content Type override → HUMAN CONFIRMS if minimalist_modern
    step 3: cross-check against B1/B2 → HUMAN RESOLVES if conflict
  ↓
B7 (human confirms all 6 → writes scenes.<id> into style_specs/<slug>.yml → COMMIT)
  ↓
Style spec is complete for this scene template. Reuse for every piece placed here.
```

B3, B6-step-2, B6-step-3 (on conflict), and B7 are the four points where Track B can pause on
`awaiting_human`. B1/B2/B4's borderline cases fall through automatically without pausing — that's the
whole point of the safe-fail defaults.

---

## 8. Verification for this module

```bash
# 1. Rule files exist and carry citations
bin/rails runner '
  %w[borderline_defaults color_role_observation].each do |n|
    r = KnowledgeBase::RuleSet.load(n)
    puts "#{n}: source=#{r.meta["source"].present?} citation=#{r.meta["citation"].present?}"
  end
'

# 2. Borderline defaults have the four axes and B3 has escalate: true
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("borderline_defaults").rules
  puts "axes present: #{%w[wall_condition furniture_weight room_type room_shape].all? { |a| r.key?(a) }}"
  puts "B3 escalates: #{r["room_type"]["escalate"] == true}"
  puts "B3 has no on_ambiguous default: #{r["room_type"]["on_ambiguous"].nil?}"
  puts "B1 default: #{r["wall_condition"]["on_ambiguous"]}"       # expect neutral
  puts "B2 default: #{r["furniture_weight"]["on_ambiguous"]}"     # expect light
  puts "B4 default: #{r["room_shape"]["on_ambiguous"]}"           # expect none
'

# 3. Color role observation table has 4 rows + the minimalist_modern override
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("color_role_observation").rules
  puts "observation rows: #{r["observation"].size}"    # expect 4
  puts "minimalist_modern default: #{r["minimalist_modern_default"]["candidate_role"]}"  # expect line_only
'

# 4. All 6 prompts render
bin/rails runner '
  %w[b1_wall_condition b2_furniture_weight b3_room_type b4_room_shape b5_space_math b6_color_role]
    .each { |n| puts "#{n}: #{Pipeline::KB_ROOT.join("prompts/#{n}.md").read.size} chars" }
'

# 5. Step classes match the registry
bin/rails runner '
  reg = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  reg["phase_1"]["track_b"]["steps"].each do |s|
    k = s["klass"].constantize
    ok = k.step_id == s["id"] && k.ownership == s["ownership"]
    puts "#{s["id"]}: #{ok ? "ok" : "MISMATCH"}"
  end
'

# 6. SceneSpecWriter refuses if style_level not locked
bin/rails runner '
  begin
    KnowledgeBase::SceneSpecWriter.write_scene_axes(
      style_slug: "nonexistent", scene_id: "test", scene_name: "T",
      template_ref: "x.yml",
      axes: { wall_condition: "neutral", furniture_weight: "light", room_type: "seated_room",
              room_shape: "none", space_math: "single", color_role: "line_only" })
    puts "FAIL — should have raised"
  rescue KnowledgeBase::IncompleteSpecError
    puts "refuses missing style spec ok"
  end
'

# 7. SceneSpecWriter rejects invalid axis values
bin/rails runner '
  KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
    slug: "b-test", name: "Test", mood: "calm_ordered",
    content_type: "minimalist_modern", frame_form: "angular")
  begin
    KnowledgeBase::SceneSpecWriter.write_scene_axes(
      style_slug: "b-test", scene_id: "s1", scene_name: "S1", template_ref: "x.yml",
      axes: { wall_condition: "invalid", furniture_weight: "light", room_type: "seated_room",
              room_shape: "none", space_math: "single", color_role: "line_only" })
    puts "FAIL — should have raised on bad axis value"
  rescue KnowledgeBase::IncompleteSpecError
    puts "rejects bad axis values ok"
  end
  File.delete(Pipeline::KB_ROOT.join("style_specs/b-test.yml").to_s) rescue nil
'

# 8. B3 hard-escalates on ambiguous (does not fall back)
bin/rails runner '
  src = File.read(Rails.root.join("app/steps/track_b/room_type.rb"))
  puts src.include?("needs_human") ? "B3 escalates on ambiguous: ok" : "B3 MISSING escalation"
  puts src.include?("on_ambiguous") ? "B3 STILL uses on_ambiguous — should not" : "B3 correctly does not use default"
'
```

**Also verify by hand:**
- B6's three substeps are all present and gated as documented: step 1 always an LLM call; step 2 a
  `needs_human` when content_type is minimalist_modern and observation ≠ line_only; step 3 a
  `needs_human` when cross-check produces a conflict.
- B7's `write_scene_axes` is never called until `context[:confirmed]` is true.
- No Track B step reads or references a Phase 2 rule file (`frame_material.yml`, `eye_level.yml`,
  etc.) — those don't exist yet at Track B time; Track B only classifies.

---

## 9. Manifest coverage

| ID | Item | Where |
|---|---|---|
| B0–B7 | All 8 Track B steps with verbatim ownership tags | §6 |
| P1-P4 | Borderline-default rules (B1→neutral, B2→light, B3→**no safe default, flag human**, B4→"none") | §2.1 + enforcement in §6.2–6.5 |
| P1-P5 | B6 step 2 (Content Type override, line_only default, p. 97) + step 3 (B1/B2 cross-check) | §2.2, §6.7 |
| P1-T5 | Color role observation → candidate role (4 rows) | §2.2 `observation` |
| — | Scene template file format with pixels_per_inch, furniture edges, eye-level anchors | §2.3 |
| — | B7's completeness validation ("could someone unfamiliar with the photo…") | §6.8 |
| — | Track B run order and pause points | §7 |

**Deferred to other modules:** the actual scene-template physical measurements are populated by the
human before B0 runs — this module defines the format but doesn't set values. Phase 2's own rule
tables (frame_material, eye_level, etc.) are read by Phase 2 steps in module 04, never by Track B —
Track B *classifies*, module 04 *acts on* the classification. That separation is deliberate and must
be preserved.
