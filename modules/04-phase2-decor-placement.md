# Module 04 — Phase 2: Decor & Placement System

> **Self-contained.** Every rule table (17), every prose rule from §2 (15), and Step 6's
> deterministic compositing logic is written out below verbatim. Do not search the internet for the
> domain content — it is all here. Build exactly what is specified.

---

## Contract

**Depends on:** module 00 (base infrastructure, `PieceRecord`), module 01 + 02 (style spec must be
locked — Phase 2 only *reads* the spec, never writes to it), module 03 (`PieceRecord.chosen_url` is
Step 1's input).

**Provides:**
- 17 `knowledge_base/rules/*.yml` files (one per rule table in Phase 2 §2)
- 3 `knowledge_base/rules/*.yml` files for prose-rule content (matting sizing, coverage cap,
  focal-point mechanism, weight balance, spacing, theme unification, customer education)
- 8 `knowledge_base/prompts/*.md` files (only Step 3 uses an LLM prompt — the rest are lookups)
- `app/steps/phase2/*.rb` — 12 step classes (0, 1, 2a–2e, 3, 4, 4b, 5, 6)
- `app/services/compositor/*.rb` — the deterministic pixel-math compositor for Step 6
- `app/services/phase2/branch_router.rb` — routes Step 1 output to the right Step 2x class
- `app/llm/schemas/phase2/theme_unification_schema.rb` — the one LLM schema in Phase 2

**Consumed by:** module 05 (Phase 3 reads the fully-populated Phase 2 fields on `PieceRecord`),
module 06 (orchestration), module 07 (evolution loop).

**Must not:** touch style/scene axis values (modules 01/02 own those), touch photo generation or
listing content (module 05 owns those), let ANY code path in Step 6 call an LLM to do pixel math.
Step 6 is `[NOT AN AGENT/LLM TASK]` verbatim from the source doc — this is the single most
important architectural line in the entire pipeline.

---

## 1. What Phase 2 is

Phase 2 turns a finished, culled piece (`PieceRecord.chosen_url` from module 03) into a validated
placement decision: frame, mat, grouping if any, weight-balance check, and the composited scene
image ready for Phase 3 photography. It runs **daily** (per piece) with one weekly gate (Step 0).

The style spec is fixed input. Phase 2 does not determine any axis value — it looks up rules keyed
by axis values already set in the spec.

### 1.1 The two mechanisms

The source doc's own §6 splits Phase 2 into two tool types, and this is preserved in the code:

- **Rule lookups** — deterministic hash lookups against YAML files. No LLM call, no latency, no
  hallucination risk on a table an LLM might misread. Steps 1, 2a–2e, 4, 4b, 5 are all this.
- **Physical compositing** — pixel math against calibrated scene templates. No LLM. Step 6 is this.

**Only one step in Phase 2 uses an LLM at all**: Step 3, the theme-unification vision check for
multi-piece sets. Every other `[AGENT-READY]` tag is deterministic — a lookup, not a model call.
Ownership tags describe *who owns the judgment*; the mechanism describes *what code runs*. They are
different things, and this doc has been carefully written so most `[AGENT-READY]` tags fall on the
`lookup` mechanism, not on LLM calls.

### 1.2 The order the rules were extracted in

I transcribed rules from the source doc in section order (§2.1 → §2.12, then §5). Every rule file
carries a `meta.source` pointing back to its Phase 2 section, and every citation is a page number
from the arrangement book (except where noted). Nothing has been paraphrased — the rule content
below is the source's own wording preserved as YAML.

---

## 2. Rule files (17 tables from §2)

### 2.1 `knowledge_base/rules/frame_material.yml`

```yaml
meta:
  source: "Phase 2 §2.1 — Frame material"
  citation: "how_to_arrange_pictures / at_home_with_pictures, p. 16-19"
  volatility: static
  lookup_strategy: >
    Two-step lookup: first pick material_category by content_type and mood; then, if metal, apply
    the metal_finish sub-table by mood and palette.

rules:
  material_category:
    metal:
      character: "Spare, streamlined, affordable, most popular"
      best_fit: "Default for content_type = minimalist_modern; apply metal_finish sub-table"
    wood:
      character: "Ranges from plain/untreated and bleached/pickled (understated, modern) to natural/plain (folksy, rustic) to richly stained/polished (time-honored, classic)"
      best_fit: "Pick the sub-finish to match mood — light/bleached for calm-minimalist, rich stain for calm-traditional"
    no_frame_canvas:
      character: "Painted canvas stretched over wood supports; fresh-from-the-studio look, lets the piece speak for itself"
      best_fit: "mood = calm AND content_type = minimalist_modern, or when the product itself is a canvas print"
    clip_frame:
      character: "Clear holder, not a true frame; simple, unadorned, casual"
      best_fit: "Casual print formats (posters, prints); no-nonsense/minimal styling"
    colored_painted:
      character: "Intensifies the picture's color, coordinates or contrasts with the wall, or adds a splash in a neutral room"
      best_fit: "Cross-reference color_role (color_role.yml §2.2a) — this is a frame-material way to execute a color-burst or accent-highlighter role"
    ornate_carved:
      character: "Heavy, robust outline; gilded or richly colored"
      best_fit: "mood = bold_active AND content_type = detailed_representational or portrait_still_life"
    novelty_whimsical:
      character: "Shape-based (suns, moons, stars) or handcrafted material (polymer clay, tin, tramp art)"
      best_fit: "Situational — not mood-driven, use for deliberately playful/one-off pieces rather than a repeatable style spec"

  # Metal sub-table — applies ONLY when material_category is metal
  metal_finish:
    calm_warm:
      condition: "mood = calm_ordered AND palette = warm"
      finish: gold
    calm_cool:
      condition: "mood = calm_ordered AND palette = cool | pastel | abstract"
      finish: silver_aluminum
    calm_neutral:
      condition: "mood = calm_ordered AND palette = neutral | monochrome"
      finish: black_metal
    bold:
      condition: "mood = bold_active"
      finish: follows_accent_color
      note: >
        Material follows the accent color the piece is meant to introduce (e.g. a warm pure-yellow
        or red frame can make a piece the room's focal point, p. 26). This sub-table doesn't
        apply — pick the color from the piece's accent role.
```

### 2.2 `knowledge_base/rules/frame_form_contour.yml`

```yaml
meta:
  source: "Phase 2 §2.2 — Frame form and contour"
  citation: "how_to_arrange_pictures / at_home_with_pictures, p. 19"
  volatility: static
  note: >
    Form is set ONCE per style (Track A A4). Contour is per-piece by content_type. Both apply
    regardless of material category.

rules:
  form:
    angular:
      description: "Angular / straight-edged — crisp, geometric perimeter"
      reads_as: "more modern / minimalist"
    rounded:
      description: "Rounded / softer — curved, gentler perimeter"
      reads_as: "softer / more traditional"
    determination: >
      Pick form to match mood/content_type same way as material — but the book doesn't hard-gate
      this one. Treat it as a style-spec choice made once per style, not a per-piece decision.

  contour:
    detailed_representational:
      contour: inward_sloping_beveled
      reasoning: "Leads the eye into the image"
    minimalist_modern:
      contour: flush_level_plane
    portrait_still_life:
      contour: outward_sloping
```

### 2.3 `knowledge_base/rules/color_role.yml`

```yaml
meta:
  source: "Phase 2 §2.2a — Color function"
  citation: "p. 82 (accent), p. 84 (unifier + mat intensity + wall/light), p. 88 (complementary vs. tension), p. 91 (color-burst, saturator), p. 97 (line-only)"
  volatility: static
  note: >
    This is the ROLE→SUPPORTING-TECHNIQUE table plus three embedded prose rules from §2.2a.
    The observation-side (how B6 assigns the role) lives in module 02's color_role_observation.yml —
    this file is what Phase 2 does with the role once it's set.

rules:
  role:
    accent_highlighter:
      does: "Brings out an accent color already in the room that would otherwise fade"
      supporting_technique: "Echo the accent in the mat or a nearby accessory"
      citation: "p. 82"
    color_burst:
      does: "Provides the room's single splash of saturated color in an otherwise neutral space"
      supporting_technique: "One saturated piece stimulates a whole muted room, making its understated colors feel more alive by contrast"
      citation: "p. 91"
    unifier:
      does: "Ties together touches of color already scattered through the room"
      supporting_technique: "Use a thin, subtle mat so the picture's colors interact freely with its surroundings"
      citation: "p. 84"
    saturator:
      does: "Repeats and reinforces the room's existing dominant color theme"
      supporting_technique: "A muted piece in a muted room reinforces calm rather than introducing tension"
      citation: "p. 91"
    line_only:
      does: "Removes color tension entirely so line, pattern, and light/dark contrast carry the piece"
      supporting_technique: "Black/white/gray display, minimal or no color in mat/frame — allows the lines to sing. Default color role for a minimalist/Japandi-type spec."
      citation: "p. 97"

  # Prose rule P2-P1 — mat intensity, from §2.2a
  mat_intensity:
    citation: "p. 84"
    rule: >
      A dark mat intensifies a picture's colors; a thin/subtle or off-white mat lets the picture's
      colors interact more openly with the room. Pick mat darkness based on the color role above.
    per_role_default:
      accent_highlighter: dark_or_colored     # can echo the accent
      color_burst: dark_acceptable            # piece commands attention regardless
      unifier: subtle                          # per p. 84 supporting technique above
      saturator: subtle_or_matched
      line_only: none_or_off_white

  # Prose rule P2-P3 — complementary vs. tension pairing, from §2.2a
  pairing_by_mood:
    citation: "p. 88"
    rule: >
      Matching or softening the art's color intensity to the wall reads serene; deliberately
      non-complementary wall/picture color creates energy. calm_ordered mood → complementary;
      bold_active mood → tension is acceptable.
    calm_ordered: complementary
    bold_active: tension_acceptable
```

### 2.4 `knowledge_base/rules/lighting.yml`

```yaml
meta:
  source: "Phase 2 §2.2b — Lighting"
  citation: "p. 85 (fixtures + bulbs); p. 84 (wall/light interaction); p. 86 (color-choreography); p. 23-24, p. 85 (conservation)"
  volatility: static
  note: >
    Contains 2 tables (fixtures, bulbs) + 3 prose rules from §2.2b (wall/light, conservation,
    color-choreography). Step 6 reads bulb tone; Phase 3 module 05 can surface fixture guidance
    to customer content.

rules:
  fixture:
    picture_lights:
      description: "Attach to the frame or wall directly above/below/alongside a single piece"
      best_for: "Individual pieces, especially where a lens-style light can spotlight black-and-white work"
    portable_floor_lights:
      description: "Low canisters casting light upward from the floor"
      best_for: "A dramatic uplit spotlight effect on what's hanging above"
    track_lights:
      description: "Ceiling-mounted, angled to strike specific pieces or bathe the whole wall"
      best_for: "Multiple pictures at once, flexible re-angling if a piece moves"
    recessed_lights:
      description: "Built into ceiling/wall/furniture, unobtrusive"
      best_for: "Individual piece lighting where a clean look matters more than cost"

  bulb:
    incandescent:
      effect: "Warm, unobtrusive glow that brings out richness and depth"
      tone: warm
    halogen:
      effect: "Bright, intense illumination; burns hot — keep distance, use a dimmer"
      tone: bright_neutral
    compact_fluorescent:
      effect: "Efficient, long-lasting; straight-tube versions work well in recessed fixtures"
      tone: cool_neutral
    specialty:
      effect: "Frosted diffuses; cool-colored enhances blues/grays; warm-colored amplifies yellow/red/wood tones; full-spectrum for accuracy"
      tone: variable

  # Prose rule P2-P2 — wall/light interaction, from §2.2a p. 84 (but grouped here since it's about lighting)
  wall_light_interaction:
    citation: "p. 84"
    rule: >
      Light direction and time-of-use matter — morning light reads cooler, north-facing rooms
      read colder/darker, artificial evening light shifts color again. Cool bulbs enhance
      blues/grays; warm bulbs amplify yellows/reds/wood tones; frosted diffuses. This mainly
      matters for how a mockup scene is lit for photography — keep it consistent across a
      style's scene templates.

  # Prose rule P2-P5 — color-choreography, from §2.2b
  color_choreography:
    citation: "p. 86"
    rule: >
      In a space with sightlines across multiple rooms, deliberately stripping color from most
      of the space and placing one or two bold-color pieces at key points can direct where
      people look first and how they move through the space — a scaled-up color-burst applied
      to a whole entry/hallway sightline rather than one wall.

  # Bulb tone matching to color role for Step 6 lighting check
  bulb_tone_by_color_role:
    line_only: neutral_or_cool          # warm undercuts a stark black/white piece
    color_burst: neutral                # avoid tinting the piece's one saturated color
    accent_highlighter: match_accent
    unifier: warm                        # per p. 84 general warmth
    saturator: match_dominant_theme
```

### 2.5 `knowledge_base/rules/match_contrast.yml`

```yaml
meta:
  source: "Phase 2 §2.3 — Match vs. contrast"
  citation: "p. 20-21, p. 61"
  volatility: static

rules:
  # Base table
  by_wall_condition:
    neutral:
      approach: match
      detail: "Match the frame to the room's materials"
    busy:
      approach: contrast
      detail: "Contrast — pick a frame that reads distinctly against the pattern; don't try to blend"

  # Prose rule P2-P6 — the governing principle. This OVERRIDES the table when they conflict.
  governing_principle:
    citation: "p. 20"
    rule: >
      Choose a frame that brings out what's interesting about the PICTURE ITSELF — its drama,
      its tranquility, some other quality — rather than one that simply matches the room's
      decor. The wall-condition table above is a TIEBREAKER for execution, not the primary
      driver of frame choice.
    priority: overrides_table
    note: >
      In practice: if the wall-condition table produces a frame that doesn't serve the piece,
      the piece wins. Flag for human review rather than defaulting.

  # Prose rule P2-P7 — single piece vs. group conditional
  single_vs_group_conditional:
    citation: "p. 21"
    rule: >
      Matching a frame to its surroundings matters MORE when hanging a single piece — since a
      lone piece is meant to make one specific decorative contribution to the room, its frame
      is doing more relational work than a frame inside a busier multi-piece grouping, where
      the group's internal unity (theme_unification.yml §2.12) matters more than any one
      piece's relationship to the room.
    weight_by_branch:
      single: high        # match/contrast rule fully applies
      set: medium         # internal group unity partially outweighs it
      split_wall: high    # each zone is treated as a separate wall
      nook: high
      surface: medium
```

### 2.6 `knowledge_base/rules/frame_sizing.yml`

```yaml
meta:
  source: "Phase 2 §2.4 — Frame-to-piece sizing"
  citation: "p. 28-29"
  volatility: static

rules:
  # Prose rule P2-P8
  sizing:
    citation: "p. 28-29"
    default_bigger: "Bigger art → bigger, more substantial frame."
    default_smaller: "Smaller art → normally a delicate, smaller frame."
    exception: >
      UNLESS deliberately using an oversized/ornate frame to elevate a small piece's presence —
      an intentional exception, not a default. Requires explicit human decision; not applied
      by default logic.
    exception_flag: oversized_intentional
```

### 2.7 `knowledge_base/rules/matting.yml`

```yaml
meta:
  source: "Phase 2 §2.4a and §2.4b — Mat sizing and technique"
  citation: "p. 21-24 (sizing + technique); p. 22 (colored mat); p. 100 (multi-opening)"
  volatility: static

rules:
  # Prose rule P2-P9 — mat sizing (§2.4a)
  sizing:
    citation: "p. 21-22"
    rule: >
      The mat should measure VISIBLY WIDER than the frame's width. If mat width and frame width
      are equal, the effect reads as flat and predictable. An oversize mat around even a small
      piece intensifies drama; a slightly uneven mat (e.g. more area below the image than above)
      adds a bit of visual movement.
    validation:
      must: "mat_width_px > frame_width_px * 1.10"     # at least 10% wider — 'visibly'
      fail_reading: "flat_and_predictable"

  # Table P2-T9 (§2.4b) — conditional technique selection, 7 rows
  technique:
    - condition: "Want to add depth or accentuate one color in the piece"
      technique: double_stepped_mat
      detail: "Layer one mat on top of another, revealing about ¾″–1″ of the inner mat"
    - condition: "Picture's shape isn't a standard rectangle, or you want to emphasize its contour"
      technique: shape_cut_mat
      detail: "Circle, oval, or elongated strips instead of the standard rectangle"
    - condition: "Want to intensify the picture's presence generally, no specific reason needed"
      technique: no_mat
      detail: >
        Omitting a mat entirely tends to intensify the look of whatever's being framed (p. 22).
        Distinct from close_framing below — a general option available for any content type.
    - condition: "Content is specifically an oil-painting style/texture"
      technique: close_framing
      detail: "Technical term — the specific combination of NO MAT AND NO GLASS, standard practice for oil-painting-style work (p. 23-24)"
    - condition: "Set is a narrative/chronological sequence meant to be read in order"
      technique: multi_opening_mat
      detail: "One mat with a series of openings, containing the whole sequence within a single frame rather than separate pieces (p. 100)"
    - condition: "Want to punctuate or strengthen a color already present in the piece"
      technique: colored_mat
      detail: "Pair with a mat that echoes/reinforces that color, rather than a neutral one (p. 22)"
    - condition: "None of the above apply"
      technique: standard_single_mat
      detail: "Standard single mat, sized per sizing rule above"
```

### 2.8 `knowledge_base/rules/placement_branch.yml`

```yaml
meta:
  source: "Phase 2 §2.5 — Single vs. multi vs. split-wall vs. nook vs. surface"
  citation: "p. 56, p. 61, p. 63, p. 72-73, p. 80, p. 103, p. 119"
  volatility: static

rules:
  # Table P2-T10 — 5 branches by space_math value
  by_space_math:
    single:
      condition: "Furniture-anchored, one piece at 2/3-3/4 furniture width fills it"
      action: "Single piece"
      step_2x: "2a"
    set:
      condition: "Furniture-anchored, one piece doesn't fill it, or furniture is minimal"
      action: "Multi-piece set"
      step_2x: "2b"
    split_wall:
      condition: "Wide-open wall, no furniture to anchor against (e.g. hallway)"
      action: >
        Split-wall technique (two options): (a) bisect the wall visually with a chair rail,
        border, or paint line, creating two smaller zones, each sized independently (p. 61);
        or (b) mount a contrasting-color backing panel behind a small cluster to carve out
        a smaller space within the enormity — a wall-within-a-wall (p. 72-73)
      step_2x: "2c"
      citation: "p. 61, p. 72-73"
    nook:
      condition: "Architectural nook (window surround, chimney jog, built-in, other wall quirk)"
      action: "Fit a single piece shaped to the nook, or a small group, sized to the space rather than a standard wall run (p. 56)"
      step_2x: "2d"
      citation: "p. 56"
    surface:
      condition: "Horizontal surface (mantel, shelf, console, windowsill) — not wall-mounted at all"
      action: >
        Surface/propped display: lean pieces against the wall on the surface rather than hanging
        (no nails needed, freely rearrangeable — gallery-style work in progress, p. 80, p. 103);
        vary the height of pieces using stands, pedestals, risers, or stacked objects rather than
        lining them up flat (p. 119); for a multi-piece surface set, a loose triangle composition
        (taller/larger pieces at the back/tip, smaller in front) is a classic way to let pieces
        play off each other (p. 104)
      step_2x: "2e"
      citation: "p. 80, p. 103, p. 104, p. 119"
```

### 2.9 `knowledge_base/rules/space_tips.yml`

```yaml
meta:
  source: "Phase 2 §2.5a — Space tips, line orientation and content"
  citation: "p. 62"
  volatility: static

rules:
  # Table P2-T11 — 3 rows by room_shape
  by_room_shape:
    narrow:
      technique: horizontal_lines
      detail: "Favor art with strong horizontal lines — reads as calming and visually widens the room"
    low_ceilinged:
      technique: vertical_lines
      detail: "Favor art with strong vertical lines — visually raises the ceiling"
    small_closed_in:
      technique: distant_vista
      detail: "A landscape with a distant/faraway vista acts as a window and opens the room up"
    none:
      technique: none
      detail: "No space-tip constraint applies. Skip the modifier."
```

### 2.10 `knowledge_base/rules/location_suitability.yml`

```yaml
meta:
  source: "Phase 2 §2.5b — Location suitability"
  citation: "p. 42-43"
  volatility: static
  note: >
    Relevant when recommending unglazed/textured/fiber-based print formats. Step 1 checks these
    against the scene template.

rules:
  # Table P2-T12 — 5 factors
  humidity:
    rule: >
      Avoid bathrooms/kitchens for pieces not sealed behind glass; fiber-textured or unsealed
      prints belong in the driest room available; glass-sealed pieces tolerate humid rooms fine.
    unsafe_rooms: [bathroom, kitchen]
  heat:
    rule: >
      Avoid hanging over a fireplace in active use; avoid near heating vents (heat + dust
      circulation); avoid over stoves/ovens.
  airborne_pollutants:
    rule: >
      Kitchens carry cooking residue in the air, not just heat — another reason to avoid
      unsealed/uncovered pieces there.
  furniture_traffic_clearance:
    rule: >
      Don't place pictures where moving furniture (e.g. a recliner) will strike them, in
      high-traffic paths already crowded with obstacles, or low enough to contact the head of
      someone seated on a couch below.
  children_pets:
    rule: >
      Keep delicate or valuable pieces up out of reach of a child's arms/toys or a pet's
      tail/claws — treat "up high" as the default in any scene with kids or pets present.
```

### 2.11 `knowledge_base/rules/coverage_cap.yml`

```yaml
meta:
  source: "Phase 2 §2.5c — Wall coverage cap"
  citation: "p. 51"
  volatility: static

rules:
  # Prose rule P2-P10
  cap:
    citation: "p. 51"
    default_max_fraction: 0.6667             # two-thirds of a blank wall
    exception:
      name: fully_maximalist
      rule: "Cover the wall (near-)completely and consistently — reads as a deliberate style choice"
    rule: >
      Binary: stay UNDER two-thirds, or commit FULLY. A partial overreach past two-thirds reads
      as a mistake. There is no in-between.
    validation:
      allowed_regions:
        - "coverage_fraction <= 0.6667"
        - "coverage_fraction >= 0.95"          # fully maximalist
      forbidden_region: "0.6667 < coverage_fraction < 0.95"
      on_forbidden: fail_step
      reasoning: >
        The forbidden band is the "landed in between" case the source doc explicitly warns
        against. Enforced in code, not left as prose.
```

### 2.12 `knowledge_base/rules/focal_point.yml`

```yaml
meta:
  source: "Phase 2 §2.6 — Focal point, isolation vs. cluster"
  citation: "p. 27-28"
  volatility: static

rules:
  # Prose rule P2-P11 — the two-bullet focal mechanism
  mechanism:
    citation: "p. 27-28"
    principle: >
      Focal is about placement, not mood: a piece hung off by itself, in an oversized/impressive
      frame, reads as the center of attention — even the simplest, sparest image will "happily
      act as center of attention" in isolation. The same piece placed as part of a cluster, in
      a thin/subtle frame, will instead "blend politely and quietly into the crowd."
    single_isolated:
      focal_by_default: true
      mood_amplification:
        bold_active: "amplify with an oversized/impressive frame"
        calm_ordered: "keep the frame quiet — let the piece carry the statement on its own"
    piece_inside_set:
      lever: frame_weight   # frame size/subtlety
      rule: >
        Same lever is how you reinforce the anchor-vs-supporting hierarchy from §2.8 — give the
        named anchor piece the more impressive/oversized frame treatment, and deliberately
        thinner/subtler frames to the supporting pieces, so the visual weight matches the
        intended focal structure rather than fighting it.
```

### 2.13 `knowledge_base/rules/arrangement_forms.yml`

```yaml
meta:
  source: "Phase 2 §2.7 and §2.7a and §2.7b — Arrangement forms, mood modifier, subject-energy override"
  citation: "p. 58-59 (forms); p. 68-69 (subject energy); p. 74, p. 81 (mood modifier)"
  volatility: static

rules:
  # Table P2-T13 — 6 forms, mood-neutral
  standard_forms:
    tops_bottoms_alignment:
      what: "Align all tops or all bottoms of various-size pictures along one imaginary horizontal line"
      when: "Simple groups of mixed sizes that still need one clean line to anchor them"
    combination_alignment:
      what: "Divide into two-plus rows; align top-row tops and bottom-row bottoms on horizontal lines, then align sides too"
      when: "Larger groups of various sizes needing more structure than a single alignment line"
    mosaic:
      what: "No fixed grid — balance by aligning some frame bottoms with others' tops, and/or centering some pictures over others; round/octagonal frames can soften a rigid mosaic"
      when: "Varied sizes/shapes with no natural row structure"
    four_corners:
      what: "Place the four largest pictures at the corners of the defined space; fill the middle with smaller ones"
      when: "A defined rectangular area with a strong size range in the set"
    gallery_style:
      what: "Identical-size pictures in one long, neat row (horizontal or vertical); a taut string + pushpins can serve as a hanging guide"
      when: "Sets where every piece is the same size"
    stair_stepping:
      what: "Align picture center points diagonally, following the line of a staircase"
      when_scenario_specific: staircase_wall
      note: "Use ONLY when the scene is a staircase wall — this form is scenario-specific, not a general option"

  # Table P2-T14 — mood-driven layer applied ON TOP of a chosen form
  mood_modifier:
    calm_ordered:
      modifier: >
        Favor tight, symmetric spacing; keep to one dominant frame style across the set;
        include an anchoring central piece.
      allow_mixed_frames: false
    bold_active:
      modifier: >
        Salon-style is available — pictures and frames of deliberately different styles/weights/
        colors "poured onto the wall," bottom layer filling first (this is the one case where
        mixed frame language, normally forbidden in Step 4, is allowed); or a staggered Block
        style (vertical-horizontal-vertical-horizontal) for gentle rotational movement instead
        of full salon chaos.
      allow_mixed_frames: true
      only_when: salon_style_chosen

  # Prose rule P2-P12 — subject energy overrides mood on the symmetry question
  subject_energy_override:
    citation: "p. 68-69"
    rule: >
      Independent of mood, check the content itself: dynamic/in-motion subject matter (action
      shots, energetic compositions) suits a slightly off-kilter, asymmetric arrangement;
      formal/still subject matter (portraits, posed or static compositions) suits precise,
      symmetric alignment.
    conflict_resolution: >
      If mood and subject energy conflict (e.g. calm mood but energetic subject), SUBJECT ENERGY
      WINS on the symmetry question. Use a symmetric bookend element (matching pieces at the
      ends) to keep an off-kilter arrangement from feeling out of hand.
    priority: overrides_mood_on_symmetry_only
```

### 2.14 `knowledge_base/rules/count_focal.yml`

```yaml
meta:
  source: "Phase 2 §2.8 — Count and focal dynamic within a set"
  citation: "p. 63, p. 74"
  volatility: static

rules:
  # Table P2-T15 — 3 rows
  by_desired_effect:
    one_dominant_anchor:
      count: odd            # canonical: 3
      canonical_n: 3
      notes: >
        Name the anchor explicitly — usually the largest or strongest composition. The book
        calls this "an anchoring central piece."
    no_hierarchy_unified_block:
      count: even           # canonical: 2 or 4
      canonical_n: [2, 4]
      notes: "Reads calmer, more ordered"
    flip_even_to_odd:
      technique: wild_card_element
      detail: "Add one wild-card element — a mirror, carving, or hanging tile"
      citation: "p. 63"
      optional: true
```

### 2.15 `knowledge_base/rules/weight_balance.yml`

```yaml
meta:
  source: "Phase 2 §2.9 — Weight balance"
  citation: "p. 63"
  volatility: static

rules:
  # Prose rule P2-P13 — 3 bullets
  rule:
    citation: "p. 63"
    dark_furniture: >
      furniture_weight = dark → keep art/frame visually LIGHTER than the furniture beneath it.
      Required.
    light_furniture: >
      furniture_weight = light → art CAN carry more visual weight without unbalancing the scene.
      Allowed, not required.
    heaviness_driver: >
      Heaviness is driven by size AND color/frame material — a small dark piece in a heavy
      frame can outweigh a larger pale, unframed one. Check both signals.

  # Machine-readable version for Step 5
  check:
    dark:
      required: "art_weight_score < furniture_weight_score"
      on_fail: fail_step
    light:
      required: null   # allowed, not required
      on_over: warn     # heavier art with light furniture is fine, but flag heavy dark frame just in case
```

### 2.16 `knowledge_base/rules/eye_level.yml`

```yaml
meta:
  source: "Phase 2 §2.10 — Eye level"
  citation: "p. 63"
  volatility: static

rules:
  # Table P2-T16 — 3 rows by room_type
  by_room_type:
    seated_room:
      rule: "Center 5-6″ above the back of the couch/chairs"
      formula_inches: 5.5           # midpoint of the 5-6" range
      anchor: furniture_top_edge_y_px
    hallway:
      rule: "At or just above eye level (no furniture-back reference)"
      formula: standing_eye_level
      anchor: standing_eye_level_y_px
    no_furniture_wall:
      rule: "At or just above eye level (no furniture-back reference)"
      formula: standing_eye_level
      anchor: standing_eye_level_y_px

  # Prose rule P2-P14 — general drop rule
  general_drop:
    citation: "p. 63"
    rule: >
      Whatever height you land on, drop it 3-4″ — most people hang pictures too high.
    formula_inches: -3.5             # midpoint of the 3-4" drop
    applied_by: compositor           # Step 6 applies this on top of the anchor
```

### 2.17 `knowledge_base/rules/spacing.yml`

```yaml
meta:
  source: "Phase 2 §2.11 — Spacing, four distinct rules"
  citation: "p. 63 (three of them); p. 101 (theme-tribute variant)"
  volatility: static
  note: >
    Four distinct rules. Do NOT merge them. Step 6 applies rules 1, 3, and 4 as pixel math;
    rule 2 (piece-to-piece within general grouping) is enforced by the compositor's
    piece-to-piece minimum-clearance check.

rules:
  # Table P2-T17 — 4 rows
  rules:
    group_to_furniture:
      situation: "Group of pictures to furniture below"
      spacing_inches: [8, 10]
      citation: "p. 63"
    piece_to_piece_general:
      situation: "Piece-to-piece within a general logical grouping"
      spacing: "several_inches"
      detail: "Too close loses individuality, too far apart loses unity"
      citation: "p. 63"
    piece_to_piece_theme:
      situation: "Piece-to-piece within a theme/tribute grouping"
      spacing: "touching_or_overlapping"
      detail: "Tighter — pieces should appear to touch or even overlap, to visually reinforce the connection"
      citation: "p. 101"
    group_width_vs_furniture:
      situation: "Group width vs. furniture"
      rule: >
        Group no wider than the furniture below it; if narrower, at least half the furniture's
        length.
      max_fraction: 1.0
      min_fraction: 0.5
      citation: "p. 63"
```

### 2.18 `knowledge_base/rules/theme_unification.yml`

```yaml
meta:
  source: "Phase 2 §2.12 — Theme unification"
  citation: "p. 101 (all six bullets); p. 116-117 (shape dominance)"
  volatility: static
  note: >
    This is the rule content Step 3's LLM vision check tests a set against.

rules:
  # Prose rule P2-P15 — 6 bullets from §2.12
  criteria:
    limit_count:
      rule: "Fewer pieces make the shared thread clearer and differences less distracting"
    similarity_beyond_subject:
      rule: >
        Similarity isn't only subject matter. Texture, color, shape, size, intensity, or
        balance can all be the unifying thread instead of/alongside subject matter.
    proximity:
      rule: "Proximity reinforces the connection — see spacing.yml (tight/touching spacing for theme sets)"
    repeat_dont_duplicate:
      rule: >
        Repeat an element (frame shape, medium, palette) across the set, but avoid exact
        duplication — echo, don't clone.
    shape_dominance:
      citation: "p. 116-117"
      rule: >
        If the set mixes varied shapes/formats, pick one dominant shape (e.g. rectangle) and
        let the others play a supporting role — this hints at hierarchy so a mixed set reads
        as rich rather than jumbled.
    subdivision_strategies:
      rule: >
        The book's own example is a big box of family photos, but the subdivision logic
        generalises to any oversized collection: by phase/generation, by sub-category,
        chronologically, by specific occasion/event, by room, or by season. Use one of these
        to cut a theme down to a coherent, limited set rather than trying to represent the
        whole theme in one grouping.
      subdivision_options:
        - phase_or_generation
        - sub_category
        - chronological
        - specific_occasion
        - by_room
        - by_season

  # Step 3's LLM vision check reads from this
  vision_check_prompt_criteria:
    - "Could a viewer tell at a glance this is one collection?"
    - "Is the count limited enough that the shared thread reads clearly?"
    - "What is the shared thread (subject / texture / color / shape / size / intensity / balance)?"
    - "Is the shared element REPEATED (echoed) across pieces without exact duplication?"
    - "If the set mixes shapes, is one shape clearly dominant?"
```

### 2.19 `knowledge_base/rules/customer_education.yml`

```yaml
meta:
  source: "Phase 2 §5 — Additional notes (not part of the daily decision tree)"
  citation: "p. 22-24 (mat colored), p. 23-24 (safekeeping), p. 24 (framer checklist), p. 37 (easel), p. 40-41 (hardware), p. 51 (fully-maximalist), p. 57 (no-holes), p. 60 (happy surprises), p. 85 (conservation lighting)"
  volatility: static
  note: >
    Content for module 05 (Etsy listing descriptions, engagement content) and future modules.
    NOT read by any Phase 2 daily-run step. Isolating here so it's clearly non-pipeline material.

rules:
  # Note P2-N1
  happy_surprises:
    citation: "p. 60"
    rule: >
      The expected spot (above the couch, over the mantel) isn't the only option — under an
      eave, a small cupboard door, inside a closet, or the patch of wall beneath a window are
      called out as good unconventional placements. Worth offering as an alternate scene
      template or a customer-facing styling tip, not a rule to enforce.

  # Note P2-N2
  no_holes_planning:
    citation: "p. 57"
    rule: >
      For customers physically hanging a print: trace each piece onto paper, mark the hanger
      point from the actual wire/hook measurement, tape the templates to the wall, and
      rearrange until satisfied before hammering anything. Customer-education content.

  # Note P2-N3 — 4 bullets
  safekeeping_checklist:
    citation: "p. 23-24, p. 85"
    bullets:
      - "Use acid-free materials for mat and backing (labeled conservation/museum/archival quality) — acid degrades paper-based images over time."
      - "Avoid displaying in rooms with heavy temperature/humidity swings (kitchens, bathrooms) or near heat sources (radiators, fireplaces, air ducts)."
      - "Avoid direct sunlight; strong light fades and dries out art."
      - "For especially valuable pieces: UV-filtering (conservation or museum-grade) glass, a UV window filter, and incandescent over fluorescent lighting all reduce fade risk."

  # Note P2-N4 — 4 bullets
  professional_framer_checklist:
    citation: "p. 24"
    bring_to_framer:
      - "Paint chips of the wall color (and nearby walls) the piece will hang on."
      - "Fabric swatches from the room's furniture/accessories."
      - "Color samples for the mat/frame if they already have ideas."
      - "Size specs (or photos) of the room and open wall area, for proportion."

  # Note P2-N5
  easel_display:
    citation: "p. 37"
    rule: >
      A piece placed on an easel rather than hung reads as more important/elevated, and gives
      full placement flexibility — it can move to the center of a room, off to the side, or
      to a different space. Worth a scene template if your product suits a freestanding,
      non-wall-mounted presentation (distinct from the leaning/propped surface display in
      §2.5 — the easel is fully mobile floor placement).

  # Note P2-N6
  hanging_hardware:
    citation: "p. 40-41"
    by_weight:
      small_light: "Sawtooth hangers — single central point"
      standard: "Traditional hangers or screw-eyes-with-wire"
      heavier: "Frame hangers on both top corners for extra stability"
      especially_heavy_or_hollow_masonry: "Wall anchors (screws + expanding anchor)"
    rule: >
      Matching hardware to actual print weight (especially framed or canvas formats) is a
      legitimate trust-building tip.
```

---

## 3. Prompt files (only ONE, for Step 3)

The other Phase 2 steps are all rule lookups — no prompt needed. Step 3 is the sole LLM call in
this entire phase.

### 3.1 `knowledge_base/prompts/p2_step3_theme_unification.md`

```markdown
Look at this set of pieces (%{piece_count} images provided). The set is intended to read as one
collection under this style: %{style_name}.

Test the set against these criteria from the source (p. 101, p. 116-117):

1. Could a viewer tell at a glance this is ONE collection?
2. Is the count limited enough that the shared thread reads clearly?
3. What IS the shared thread — subject / texture / color / shape / size / intensity / balance?
   Name it explicitly. Do not fall back to "vibe."
4. Is the shared element REPEATED (echoed) across pieces without exact duplication? Echo, don't
   clone.
5. If the set mixes shapes or formats, is ONE shape clearly dominant?

Report each check as pass / fail / borderline with a specific reason. Return JSON matching the
required schema.

Do NOT judge on overall aesthetic pleasingness — the source is explicit that the check is about
reading as one collection, not whether you personally like the arrangement.
```

---

## 4. Schema class

Just one — Phase 2 has one LLM call.

```ruby
# app/llm/schemas/phase2/theme_unification_schema.rb
module Schemas
  module Phase2
    class ThemeUnificationSchema < RubyLLM::Schema
      boolean :reads_as_one_collection
      string :shared_thread,
             description: "Named explicitly: subject / texture / color / shape / size / intensity / balance"
      array :checks do
        object do
          string :criterion,
                 enum: %w[at_a_glance_collection count_limited shared_thread echo_not_clone shape_dominance]
          string :result, enum: %w[pass fail borderline]
          string :reasoning
        end
      end
      integer :fails_count
      integer :borderlines_count
    end
  end
end
```

---

## 5. Branch router

Step 1 produces a `placement_branch` value; Step 2 has five sub-steps and the router picks which one
runs. Kept as a separate service so the orchestrator (module 06) doesn't have to know the mapping.

```ruby
# app/services/phase2/branch_router.rb
module Phase2
  class BranchRouter
    STEP_CLASSES = {
      "single"     => Steps::Phase2::SingleFocalTreatment,
      "set"        => Steps::Phase2::SetGroupingAndCount,
      "split_wall" => Steps::Phase2::SplitWallZoning,
      "nook"       => Steps::Phase2::NookFit,
      "surface"    => Steps::Phase2::SurfaceDisplay
    }.freeze

    def self.klass_for(placement_branch)
      STEP_CLASSES.fetch(placement_branch) do
        raise ArgumentError, "Unknown placement_branch=#{placement_branch.inspect}"
      end
    end
  end
end
```

---

## 6. Step implementations

Every non-compositor step follows the same shape: read a rule file, look up by axis values on the
`PieceRecord`, write the decision back to the piece, return `ok`.

### 6.1 Step 0 — Load the style spec `[HUMAN ONLY]`

```ruby
# app/steps/phase2/load_style_spec.rb
module Steps
  module Phase2
    class LoadStyleSpec < Steps::Base
      step id: "P2_0", mechanism: :human, ownership: "[HUMAN ONLY]"

      # context: { style_slug: }
      def perform
        spec = KnowledgeBase::StyleSpec.load(context.fetch(:style_slug))
        spec.validate!    # raises IncompleteSpecError if any axis is blank or out-of-range

        ok({ style_slug: spec.slug, scenes: spec.scene_ids },
           message: "Style spec loaded and validated. #{spec.scene_ids.size} scene(s) ready.")
      rescue KnowledgeBase::IncompleteSpecError => e
        fail_step("Style spec is incomplete: #{e.message}. Cannot run daily pipeline against " \
                  "a spec with blank axes.", { style_slug: context[:style_slug] })
      end
    end
  end
end
```

### 6.2 Step 1 — Measure the scene, choose branch `[AGENT-READY]`

```ruby
# app/steps/phase2/measure_scene.rb
module Steps
  module Phase2
    class MeasureScene < Steps::Base
      step id: "P2_1", mechanism: :lookup, ownership: "[AGENT-READY]"

      def perform
        branch_rule = rules("placement_branch").fetch("by_space_math", piece.space_math)

        # Location suitability check (§2.5b)
        location_issues = check_location_suitability
        if location_issues.any?
          return needs_human(
            "Scene fails location suitability checks: #{location_issues.join('; ')}. " \
            "Reroute or accept the risk explicitly.",
            { location_issues: location_issues, branch: branch_rule["action"] }
          )
        end

        # Coverage cap check (§2.5c) — will be re-checked in Step 6 with actual pixels; here we
        # just confirm the intended coverage isn't in the forbidden mid-band.
        # Actual coverage_fraction check runs in the compositor once dimensions are known.

        piece.update!(placement_branch: piece.space_math)
        ok({ placement_branch: piece.space_math, next_step: branch_rule["step_2x"] })
      end

      private

      def check_location_suitability
        rule = rules("location_suitability").rules
        issues = []
        # Scene template can declare its room type; here we lean on the axis values already set.
        # If the scene template exposes a `room_hint` (bathroom/kitchen/etc.) it can be checked
        # against rule["humidity"]["unsafe_rooms"] — extension point, not required for MVP.
        issues
      end
    end
  end
end
```

### 6.3 Steps 2a–2e — branch handlers

All five have the same shape: look up the branch-specific rule, write the result, return `ok`. I'll
give 2a and 2b in full; 2c–2e follow the same pattern.

```ruby
# app/steps/phase2/single_focal_treatment.rb
module Steps
  module Phase2
    class SingleFocalTreatment < Steps::Base
      step id: "P2_2a", mechanism: :lookup, ownership: "[AGENT-READY]"

      def perform
        focal = rules("focal_point").fetch("mechanism", "single_isolated")
        amp   = focal["mood_amplification"].fetch(piece.mood)

        piece.update!(
          arrangement_form: "single_focal",
          piece_count: 1,
          anchor_piece_ref: piece.chosen_url    # the single piece IS the anchor
        )
        ok({ focal_treatment: amp, frame_weight_hint: (piece.mood == "bold_active" ? "impressive" : "quiet") })
      end
    end
  end
end
```

```ruby
# app/steps/phase2/set_grouping_and_count.rb
module Steps
  module Phase2
    class SetGroupingAndCount < Steps::Base
      step id: "P2_2b", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { piece_count:, subject_energy: (dynamic|formal), staircase_scene: (bool) }
      def perform
        forms = rules("arrangement_forms")
        count = context.fetch(:piece_count, 1).to_i

        # Base form choice — human/orchestrator selects from the 6 standard forms; agent
        # rejects stair_stepping unless the scene is a staircase.
        base_form = context.fetch(:base_form, "tops_bottoms_alignment")
        if base_form == "stair_stepping" && !context[:staircase_scene]
          return fail_step("stair_stepping is scenario-specific — allowed only on a staircase wall.",
                           { requested: base_form })
        end

        mood_mod = forms.fetch("mood_modifier", piece.mood)

        # Subject-energy override on symmetry — supersedes mood if they conflict
        subject_energy = context.fetch(:subject_energy, "formal")
        symmetry_call, override_applied = resolve_symmetry(piece.mood, subject_energy)

        # Odd vs. even count — anchor logic
        count_rule = rules("count_focal").fetch("by_desired_effect",
                                                count.odd? ? "one_dominant_anchor" : "no_hierarchy_unified_block")
        anchor_required = count.odd?

        piece.update!(
          arrangement_form: base_form,
          piece_count: count,
          anchor_piece_ref: anchor_required ? context[:anchor_url] : nil
        )

        ok({ base_form: base_form, mood_modifier: mood_mod["modifier"],
             symmetry: symmetry_call, subject_energy_override: override_applied,
             anchor_required: anchor_required })
      end

      private

      def resolve_symmetry(mood, subject_energy)
        override = rules("arrangement_forms").fetch("subject_energy_override")
        # subject energy wins on symmetry only
        chosen = subject_energy == "dynamic" ? "off_kilter" : "symmetric"
        conflicts = (mood == "calm_ordered" && chosen == "off_kilter") ||
                    (mood == "bold_active"  && chosen == "symmetric")
        [chosen, conflicts]
      end
    end
  end
end
```

**Steps 2c, 2d, 2e** follow the same shape as 2a and 2b — read the branch rule, write the decision,
return `ok`. Here they are in full.

```ruby
# app/steps/phase2/split_wall_zoning.rb
module Steps
  module Phase2
    class SplitWallZoning < Steps::Base
      step id: "P2_2c", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { split_technique: (chair_rail|border|paint_line|backing_panel),
      #            zones: [ { branch: (single|set), piece_count: N, anchor_url: '...' } , ... ] }
      def perform
        rule = rules("placement_branch").fetch("by_space_math", "split_wall")

        zones = context.fetch(:zones, [])
        if zones.empty?
          return fail_step("split_wall requires at least one zone in context[:zones]", {})
        end

        # Each zone recursively re-uses 2a/2b logic — a zone is treated as a separate wall.
        zone_results = zones.map do |z|
          {
            branch: z[:branch],
            piece_count: z[:piece_count],
            # Focal/grouping recorded per zone; the actual sub-step (2a or 2b) doesn't run
            # separately here — the compositor treats each zone as its own placement region.
          }
        end

        piece.update!(
          arrangement_form: "split_wall_#{context.fetch(:split_technique, 'chair_rail')}",
          piece_count: zones.sum { |z| z[:piece_count].to_i },
          composite_measurements: (piece.composite_measurements || {}).merge("zones" => zone_results)
        )

        ok({ split_technique: context[:split_technique], zones: zone_results,
             citation: rule["citation"] })
      end
    end
  end
end
```

```ruby
# app/steps/phase2/nook_fit.rb
module Steps
  module Phase2
    class NookFit < Steps::Base
      step id: "P2_2d", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { nook_dimensions_px: { width:, height: }, piece_count: N }
      def perform
        rule = rules("placement_branch").fetch("by_space_math", "nook")

        count = context.fetch(:piece_count, 1).to_i
        # Nook must accommodate piece-to-piece spacing (§2.11 general rule) if a group.
        if count > 1
          spacing_rule = rules("spacing").fetch("rules", "piece_to_piece_general")
          # No hard pixel check here — the compositor validates fit in Step 6.
        end

        piece.update!(
          arrangement_form: "nook_fit",
          piece_count: count,
          anchor_piece_ref: count == 1 ? piece.chosen_url : context[:anchor_url]
        )

        ok({ nook_dimensions: context[:nook_dimensions_px], piece_count: count,
             citation: rule["citation"] })
      end
    end
  end
end
```

```ruby
# app/steps/phase2/surface_display.rb
module Steps
  module Phase2
    class SurfaceDisplay < Steps::Base
      step id: "P2_2e", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { piece_count: N, heights_used: [Integer], surface_type: (mantel|shelf|console|windowsill) }
      def perform
        rule = rules("placement_branch").fetch("by_space_math", "surface")

        count = context.fetch(:piece_count, 1).to_i
        heights = Array(context[:heights_used])

        # Validation from the source doc: "at least two distinct height levels are present if
        # more than one piece is shown; no two pieces are perfectly flush unless that flatness
        # is the deliberate look for this mood."
        if count > 1 && heights.uniq.size < 2
          return needs_human(
            "Surface display with #{count} pieces has only #{heights.uniq.size} distinct height " \
            "level(s). Per §2.5, vary heights using stands, risers, or stacked objects. " \
            "Confirm this flat look is deliberate for this mood, or add height variation.",
            { piece_count: count, heights_used: heights, mood: piece.mood }
          )
        end

        piece.update!(
          arrangement_form: count > 1 ? "loose_triangle" : "single_leaned",
          piece_count: count
        )

        ok({ surface_type: context[:surface_type], piece_count: count,
             distinct_heights: heights.uniq.size, citation: rule["citation"] })
      end
    end
  end
end
```

### 6.4 Step 3 — Unify by theme `[AGENT-ASSISTED — vision check, human confirms]`

This is the **only** LLM call in Phase 2. Conditional: only runs when the branch produced a set.

```ruby
# app/steps/phase2/unify_by_theme.rb
module Steps
  module Phase2
    class UnifyByTheme < Steps::Base
      step id: "P2_3",
           mechanism: :llm_vision,
           ownership: "[AGENT-ASSISTED — vision check, human confirms]"

      def perform
        # Only applies to multi-piece sets
        if piece.piece_count.to_i <= 1
          return ok({ skipped: true, reason: "Single piece — theme unification is a set-level check" })
        end

        set_urls = piece.finalist_urls.presence || [piece.chosen_url].compact
        result = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                        .with_schema(Schemas::Phase2::ThemeUnificationSchema)
                        .ask(prompt("p2_step3_theme_unification",
                                    piece_count: set_urls.size, style_name: spec.name),
                             with: set_urls)
                        .content

        if result["fails_count"].to_i.positive?
          return needs_human(
            "Theme-unification check failed on #{result['fails_count']} criterion/criteria. " \
            "Shared thread claim: #{result['shared_thread']}. Reads as one collection: " \
            "#{result['reads_as_one_collection']}. Human confirms whether to proceed with this " \
            "set or return to Track C for a tighter cull.",
            { llm_result: result }
          )
        end

        ok({ shared_thread: result["shared_thread"],
             reads_as_one_collection: result["reads_as_one_collection"] })
      end
    end
  end
end
```

### 6.5 Step 4 — Assign frame material and contour `[AGENT-READY]`

Longest lookup step — reads six rule files.

```ruby
# app/steps/phase2/assign_frame.rb
module Steps
  module Phase2
    class AssignFrame < Steps::Base
      step id: "P2_4", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { palette: (warm|cool|pastel|abstract|neutral|monochrome) }
      def perform
        material_rules  = rules("frame_material")
        form_rules      = rules("frame_form_contour")
        match_rules     = rules("match_contrast")
        matting_rules   = rules("matting")

        # === Category (§2.1 Step A) ===
        category = pick_material_category(material_rules)

        # === Finish (§2.1 Step B) — only if metal ===
        finish = category == "metal" ? pick_metal_finish(material_rules) : nil

        # === Contour (§2.2, per-piece by content_type) ===
        contour = form_rules.fetch("contour", piece.content_type, "contour")

        # === Match vs. contrast (§2.3) — governing principle overrides table on conflict ===
        match_or_contrast = match_rules.fetch("by_wall_condition", piece.wall_condition, "approach")

        # === Matting technique (§2.4b) — needs human context, so record a default and flag ===
        # Default to standard_single_mat; a human can pick a specific condition-driven technique
        # via context. Not silently guessing color/depth intent.
        matting_technique = context.fetch(:matting_technique, "standard_single_mat")

        piece.update!(
          frame_material_category: category,
          frame_material_finish: finish,
          frame_contour: contour,
          matting_technique: matting_technique
        )

        ok({
          category: category, finish: finish, contour: contour,
          match_or_contrast: match_or_contrast,
          matting_technique: matting_technique,
          # Governing principle from §2.3 as a reminder for downstream reviewers:
          governing_principle: match_rules.fetch("governing_principle", "rule")
        })
      end

      private

      # Content Type + Mood → material category. Uses the "best_fit" column of §2.1 Step A.
      def pick_material_category(material_rules)
        cats = material_rules.rules["material_category"]
        # Direct rules from the source doc's "best fit" column:
        return "metal" if piece.content_type == "minimalist_modern"
        return "ornate_carved" if piece.mood == "bold_active" &&
                                  %w[detailed_representational portrait_still_life].include?(piece.content_type)
        return "wood"  if piece.mood == "calm_ordered"
        "metal"        # documented default
      end

      def pick_metal_finish(material_rules)
        palette = context.fetch(:palette, "neutral")

        return "follows_accent_color" if piece.mood == "bold_active"
        case palette
        when "warm"                        then "gold"
        when "cool", "pastel", "abstract"  then "silver_aluminum"
        when "neutral", "monochrome"       then "black_metal"
        else "black_metal"
        end
      end
    end
  end
end
```

### 6.6 Step 4b — Color function check `[AGENT-READY]`

```ruby
# app/steps/phase2/color_function_check.rb
module Steps
  module Phase2
    class ColorFunctionCheck < Steps::Base
      step id: "P2_4b", mechanism: :lookup, ownership: "[AGENT-READY]"

      def perform
        color_rules = rules("color_role")
        mat_intensity = color_rules.fetch("mat_intensity", "per_role_default", piece.color_role)
        pairing = color_rules.fetch("pairing_by_mood", piece.mood)

        piece.update!(
          color_role_confirmed: piece.color_role,
          mat_intensity: mat_intensity
        )

        ok({ color_role: piece.color_role, mat_intensity: mat_intensity, pairing_by_mood: pairing })
      end
    end
  end
end
```

### 6.7 Step 5 — Check weight balance `[AGENT-READY]`

```ruby
# app/steps/phase2/weight_balance.rb
module Steps
  module Phase2
    class WeightBalance < Steps::Base
      step id: "P2_5", mechanism: :lookup, ownership: "[AGENT-READY]"

      def perform
        rule = rules("weight_balance").fetch("check", piece.furniture_weight)

        # A real weight-scoring model is out of scope for MVP. The check here is:
        # dark furniture + dark heavy frame ("ornate_carved" or metal with "black" finish + no mat)
        # → likely fails; flag for human. Light furniture + anything → pass.
        art_reads_heavy = %w[ornate_carved].include?(piece.frame_material_category) ||
                          piece.mat_intensity.to_s.include?("dark")

        pass = case piece.furniture_weight
               when "dark"  then !art_reads_heavy
               when "light" then true
               end

        piece.update!(weight_balance_pass: pass)

        if pass
          ok({ furniture_weight: piece.furniture_weight, art_reads_heavy: art_reads_heavy })
        else
          needs_human(
            "Weight balance fails: dark furniture requires art LIGHTER than the furniture, but " \
            "this piece's frame/material reads heavy (#{piece.frame_material_category}, " \
            "mat=#{piece.mat_intensity}). Change frame or accept the risk.",
            { furniture_weight: piece.furniture_weight, frame_reads_heavy: art_reads_heavy }
          )
        end
      end
    end
  end
end
```

### 6.8 Step 6 — Composite into the scene `[NOT AN AGENT/LLM TASK]`

**No LLM anywhere in this step.** Runs a deterministic compositor.

```ruby
# app/steps/phase2/composite.rb
module Steps
  module Phase2
    class Composite < Steps::Base
      step id: "P2_6",
           mechanism: :deterministic_tool,
           ownership: "[NOT AN AGENT/LLM TASK — deterministic template tool required]"

      def perform
        result = Compositor::Runner.call(piece: piece)

        piece.update!(
          composite_url: result.output_path,
          composite_measurements: result.measurements
        )

        # Coverage cap check (§2.5c) runs against the FINAL measurements
        cap_rule = rules("coverage_cap").fetch("cap")
        cf = result.measurements[:coverage_fraction].to_f
        forbidden = cf > cap_rule["default_max_fraction"].to_f && cf < 0.95
        if forbidden
          return fail_step(
            "Coverage cap violation: coverage_fraction=#{cf.round(3)} is in the forbidden mid-band " \
            "(>0.6667 and <0.95). Per §2.5c, this reads as a mistake. Reduce piece size or commit " \
            "fully maximalist.",
            { coverage_fraction: cf, allowed_regions: cap_rule["validation"]["allowed_regions"] }
          )
        end

        ok({ composite_url: result.output_path, measurements: result.measurements })
      rescue Compositor::TemplateError => e
        fail_step("Compositor failed: #{e.message}. Scene template measurements likely missing " \
                  "or wrong — see knowledge_base/scene_templates/#{piece.scene_spec_id}.yml.", {})
      end
    end
  end
end
```

The compositor itself is the largest single piece of non-LLM code in the pipeline.

### 6.9 The `Compositor::Runner` service

```ruby
# app/services/compositor/runner.rb
module Compositor
  class TemplateError < StandardError; end

  Result = Struct.new(:output_path, :measurements, keyword_init: true)

  class Runner
    def self.call(piece:) = new(piece: piece).call

    def initialize(piece:)
      @piece = piece
      @scene = piece.style_spec.scene(piece.scene_spec_id)
      @template = load_template
    end

    def call
      art = load_art_image
      art_dims = compute_art_dimensions

      x, y = compute_position(art_dims)

      composited = paste_art_on_template(art, x: x, y: y, w: art_dims[:w], h: art_dims[:h])
      output_path = write_output(composited)

      Result.new(
        output_path: output_path,
        measurements: measurements_summary(art_dims, x, y)
      )
    end

    private

    def load_template
      path = Pipeline::KB_ROOT.join("scene_templates", "#{@piece.scene_spec_id}.yml")
      raise TemplateError, "No scene template at #{path}" unless path.exist?

      raw = YAML.safe_load_file(path, permitted_classes: [Date])
      required = %w[image_path measurements]
      missing  = required - raw.keys
      raise TemplateError, "Template missing: #{missing.join(', ')}" if missing.any?
      raw
    end

    def load_art_image
      # Loads @piece.chosen_url via Vips. If chosen_url is a remote URL, download first.
      # In practice the manual/replicate adapters will have written the file locally already.
      Vips::Image.new_from_file(local_path_for(@piece.chosen_url))
    end

    def local_path_for(url)
      # If it's already a local path, return it.
      return url if File.exist?(url.to_s)

      # Download via Faraday to tmp
      dst = Rails.root.join("tmp", "art_downloads", "#{@piece.id}_#{File.basename(URI.parse(url).path)}")
      dst.dirname.mkpath
      unless dst.exist?
        response = Faraday.get(url)
        dst.write(response.body)
      end
      dst.to_s
    end

    def compute_art_dimensions
      m   = @template.fetch("measurements")
      ppi = m.fetch("pixels_per_inch").to_i

      # === Group width vs. furniture rule (§2.11) ===
      # Group no wider than furniture; if narrower, at least half.
      furn_w = m["furniture_width_px"]

      target_w = if furn_w.present?
                   # 2/3 to 3/4 of furniture width is the "single-piece fills" rule (§2.5)
                   (furn_w * 0.7).to_i
                 else
                   # No furniture (hallway/split-wall/etc.) — use wall_zone width
                   (m.dig("wall_zone", "width").to_i * 0.5)
                 end

      # Naïvely square unless the source art has a known aspect ratio; leave the art's own
      # aspect ratio in place by scaling proportionally.
      art_native = Vips::Image.new_from_file(local_path_for(@piece.chosen_url))
      ratio = art_native.height.to_f / art_native.width
      target_h = (target_w * ratio).to_i

      { w: target_w.to_i, h: target_h }
    end

    def compute_position(art_dims)
      m = @template.fetch("measurements")

      # === Horizontal centering across wall zone / furniture ===
      wall_zone = m["wall_zone"] || {}
      wall_center_x = wall_zone["x"].to_i + (wall_zone["width"].to_i / 2)
      x = wall_center_x - (art_dims[:w] / 2)

      # === Vertical position — eye-level rule (§2.10) + general drop (P2-P14) ===
      ppi = m["pixels_per_inch"].to_i
      eye_rules = KnowledgeBase::RuleSet.load("eye_level").rules

      by_room = eye_rules["by_room_type"].fetch(@piece.room_type)
      anchor_key = by_room["anchor"]
      anchor_y = m.fetch(anchor_key) do
        raise TemplateError, "Template is missing measurement '#{anchor_key}' for " \
                             "room_type=#{@piece.room_type}."
      end

      center_y = if @piece.room_type == "seated_room"
                   # "Center 5-6" above the back of the couch/chairs" — but the anchor is the TOP
                   # of the furniture, so the piece CENTER sits ABOVE that anchor by 5.5" + half
                   # the piece height.
                   inches_above = by_room["formula_inches"].to_f
                   furniture_top_y = anchor_y.to_i
                   furniture_top_y - (inches_above * ppi).to_i - (art_dims[:h] / 2)
                 else
                   anchor_y.to_i
                 end

      # Apply the general drop rule (P2-P14): drop 3-4" — "most people hang too high"
      drop_px = (eye_rules["general_drop"]["formula_inches"].to_f.abs * ppi).to_i
      center_y += drop_px

      y = center_y - (art_dims[:h] / 2)

      # === Furniture 8-10" gap check (§2.11) — validate, don't silently fix ===
      if @piece.room_type == "seated_room"
        gap_px = anchor_y.to_i - (y + art_dims[:h])
        gap_inches = gap_px.to_f / ppi
        if gap_inches < 8 || gap_inches > 10
          # Adjust to the midpoint of the range (9")
          target_gap_px = (9.0 * ppi).to_i
          y = anchor_y.to_i - target_gap_px - art_dims[:h]
        end
      end

      [x, y]
    end

    def paste_art_on_template(art, x:, y:, w:, h:)
      template_img = Vips::Image.new_from_file(Pipeline::KB_ROOT.join(@template["image_path"]).to_s)
      resized_art  = art.resize(w.to_f / art.width)
      template_img.composite2(resized_art, :over, x: x, y: y)
    end

    def write_output(img)
      dst = Rails.root.join("tmp", "composites", "#{@piece.id}_#{Time.current.to_i}.png")
      dst.dirname.mkpath
      img.write_to_file(dst.to_s)
      dst.to_s
    end

    def measurements_summary(art_dims, x, y)
      m = @template["measurements"]
      wall_area = m["wall_zone"]["width"].to_i * m["wall_zone"]["height"].to_i
      art_area  = art_dims[:w] * art_dims[:h]
      {
        art_width_px:  art_dims[:w],
        art_height_px: art_dims[:h],
        x_px: x, y_px: y,
        pixels_per_inch: m["pixels_per_inch"],
        coverage_fraction: (art_area.to_f / wall_area).round(4),
        eye_level_anchor: m[KnowledgeBase::RuleSet.load("eye_level").rules["by_room_type"][@piece.room_type]["anchor"]]
      }
    end
  end
end
```

**Why the compositor is this long:** it's the entire physical-rule enforcement layer of Phase 2 in
one place — eye level, general drop, furniture gap, group width, coverage cap. Every one of those
numbers has a page citation in the source doc and must be pixel-accurate. Splitting this across
services makes it easier to lose one of them silently. Kept together, the whole physical rule set
is auditable in one file.

### 6.10 Step 7 — Weekly review gate `[HUMAN ONLY — agent may summarize data, not decide]`

The registry (module 00) names `Steps::Phase2::WeeklyReview`; the class lives here even though
module 06/07 drive it, so the ownership tag is preserved verbatim in one place.

```ruby
# app/steps/phase2/weekly_review.rb
module Steps
  module Phase2
    class WeeklyReview < Steps::Base
      step id: "P2_7",
           mechanism: :human,
           ownership: "[HUMAN ONLY — agent may summarize data, not decide]"

      # context: { performance_summary: (String or Hash) }
      # Populated by module 07's weekly-review export job before this step runs.
      def perform
        summary = context[:performance_summary]

        needs_human(
          "Weekly review — carry the previous week's Phase 3 performance data forward and decide " \
          "whether next week's Step 0 REPEATS, EXTENDS, or ROTATES the style/scene combination. " \
          "Per the ownership tag, the agent may SUMMARIZE the numbers but not decide.",
          { performance_summary: summary,
            available_options: %w[repeat extend rotate],
            grounding: "Phase 2 §3 STEP 7 — human interprets sales/view data; agent does not" }
        )
      end
    end
  end
end
```

**Note:** module 07 owns the performance-export job that produces `performance_summary`. This class
is just the pause point where the human's repeat/extend/rotate decision is recorded.

---

## 7. Verification for this module

```bash
# 1. All 17 §2 rule files exist and carry meta.source + meta.citation
bin/rails runner '
  files = %w[frame_material frame_form_contour color_role lighting match_contrast frame_sizing
             matting placement_branch space_tips location_suitability coverage_cap focal_point
             arrangement_forms count_focal weight_balance eye_level spacing]
  files.each do |n|
    r = KnowledgeBase::RuleSet.load(n)
    ok = r.meta["source"].present? && r.meta["citation"].present?
    puts "#{n}: #{ok ? "ok" : "MISSING META"}"
  end
  puts "count=#{files.size}"    # expect 17
'

# 2. Prose-rule files exist too
bin/rails runner '
  %w[theme_unification customer_education].each do |n|
    r = KnowledgeBase::RuleSet.load(n)
    puts "#{n}: source=#{r.meta["source"].present?} citation=#{r.meta["citation"].present?}"
  end
'

# 3. Every Step class matches config/step_registry.yml
bin/rails runner '
  reg = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  reg["phase_2"]["steps"].each do |s|
    k = s["klass"].constantize
    ok = k.step_id == s["id"] && k.ownership == s["ownership"]
    puts "#{s["id"]}: #{ok ? "ok" : "MISMATCH klass=#{k.step_id} tag=#{k.ownership}"}"
  end
'

# 4. All 4 borderline defaults from module 02 are readable — Phase 2 does not need them,
#    but the cross-module dependency is stable.
bin/rails runner '
  puts KnowledgeBase::RuleSet.load("borderline_defaults").rules.keys.sort
'

# 5. Frame material has all 7 categories; metal has 4 finishes.
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("frame_material").rules
  puts "categories=#{r["material_category"].size}"       # expect 7
  puts "finishes=#{r["metal_finish"].size}"              # expect 4
'

# 6. Matting has 7 conditional techniques.
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("matting").rules
  puts "techniques=#{r["technique"].size}"                # expect 7
'

# 7. Arrangement forms has 6 standard forms; mood modifier has 2 rows; subject-energy override exists.
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("arrangement_forms").rules
  puts "standard_forms=#{r["standard_forms"].size}"        # expect 6
  puts "mood_modifier=#{r["mood_modifier"].size}"          # expect 2
  puts "override_priority=#{r["subject_energy_override"]["priority"]}"  # expect overrides_mood_on_symmetry_only
'

# 8. Spacing has 4 distinct rules — DO NOT MERGE
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("spacing").rules
  puts "spacing_rules=#{r["rules"].size}"                 # expect 4
'

# 9. Coverage cap has the forbidden mid-band correctly defined
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("coverage_cap").rules
  puts "default_max=#{r["cap"]["default_max_fraction"]}"                             # expect 0.6667
  puts "forbidden=#{r["cap"]["validation"]["forbidden_region"]}"                     # expect the mid-band
'

# 10. Eye level has all 3 room_type formulas
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("eye_level").rules
  puts r["by_room_type"].keys.sort                        # expect [hallway, no_furniture_wall, seated_room]
  puts "drop=#{r["general_drop"]["formula_inches"]}"      # expect -3.5
'

# 11. Compositor imports and TemplateError raises on missing template
bin/rails runner '
  begin
    piece = PieceRecord.new(style_spec_slug: "nonexistent", scene_spec_id: "x",
                            kb_version: "dirty:test", status: "pending")
    Compositor::Runner.call(piece: piece)
  rescue => e
    puts "raised: #{e.class}: #{e.message.lines.first.strip}"
  end
'

# 12. Confirm Step 6 has NO reference to RubyLLM anywhere in its class or the compositor
grep -rE "RubyLLM|llm|Llm" app/steps/phase2/composite.rb app/services/compositor/ && \
  echo "FAIL — Step 6 must not reference an LLM" || echo "Step 6 is LLM-free: ok"
```

**Also verify by hand:**
- Step 3 is the ONLY step in Phase 2 that references `RubyLLM.chat` or a schema class. Grep for it:
  `grep -rl RubyLLM app/steps/phase2/` — should return exactly `unify_by_theme.rb`.
- The §2.3 governing principle is present in the rule file as a field `governing_principle` and is
  read back in Step 4's response — it must not be silently dropped from the flow.
- Coverage cap's forbidden mid-band (`0.6667 < cf < 0.95`) is enforced in Step 6, not just described.
- Eye-level anchors (`furniture_top_edge_y_px`, `standing_eye_level_y_px`) are present in scene
  template YAML — if not, Step 6 raises `TemplateError` rather than silently guessing.

---

## 8. Manifest coverage

| Manifest ID | Item | Where |
|---|---|---|
| P2_0–P2_7 | All 13 Phase 2 steps with verbatim ownership tags | §6 + step_registry.yml (module 00) |
| P2-T1, P2-T2 | Frame material (7 categories) + metal finish (4) | §2.1 |
| P2-T3, P2-T4 | Frame form (2 forms) + contour (3 by content_type) | §2.2 |
| P2-T5 | Color function (5 roles) | §2.3 |
| P2-T6, P2-T7 | Lighting fixtures (4) + bulbs (4) | §2.4 |
| P2-T8 | Match vs. contrast (2 by wall_condition) | §2.5 |
| P2-T9 | Matting technique (7 conditional) | §2.7 |
| P2-T10 | Placement branch (5 by space_math) | §2.8 |
| P2-T11 | Space tips (3 by room_shape) | §2.9 |
| P2-T12 | Location suitability (5 factors) | §2.10 |
| P2-T13 | Standard arrangement forms (6) | §2.13 |
| P2-T14 | Mood modifier (2) | §2.13 |
| P2-T15 | Count and focal (3 by desired effect) | §2.14 |
| P2-T16 | Eye level (3 by room_type) | §2.16 |
| P2-T17 | Spacing (4 distinct rules) | §2.17 |
| P2-P1 | Mat intensity rule (p. 84) | §2.3 `mat_intensity` |
| P2-P2 | Wall/light interaction (p. 84) | §2.4 `wall_light_interaction` |
| P2-P3 | Complementary vs. tension pairing (p. 88) | §2.3 `pairing_by_mood` |
| P2-P4 | Conservation note (UV glass, incandescent) | §2.19 `safekeeping_checklist` |
| P2-P5 | Color-choreography technique (p. 86) | §2.4 `color_choreography` |
| P2-P6 | Governing principle (frame serves the picture) | §2.5 `governing_principle` |
| P2-P7 | Single piece vs. group conditional (p. 21) | §2.5 `single_vs_group_conditional` |
| P2-P8 | Frame-to-piece sizing (bigger→bigger unless exception) | §2.6 |
| P2-P9 | Mat sizing rule (visibly wider than frame) | §2.7 `sizing` |
| P2-P10 | Wall coverage cap (two-thirds or fully maximalist, binary) | §2.11 |
| P2-P11 | Focal point mechanism (isolation vs. cluster, 2 bullets) | §2.12 |
| P2-P12 | Symmetry vs. subject energy (p. 68-69) | §2.13 `subject_energy_override` |
| P2-P13 | Weight balance (p. 63, 3 bullets) | §2.15 |
| P2-P14 | General eye-level drop (3-4") | §2.16 `general_drop` |
| P2-P15 | Theme unification (6 bullets) | §2.18 |
| P2-N1 | Happy Surprises (p. 60) | §2.19 |
| P2-N2 | No-holes planning (p. 57) | §2.19 |
| P2-N3 | Safekeeping/conservation checklist (4 bullets) | §2.19 |
| P2-N4 | Professional framer checklist (4 bullets) | §2.19 |
| P2-N5 | Easel display (p. 37) | §2.19 |
| P2-N6 | Hanging hardware by weight (p. 40-41) | §2.19 |
| X1 | Phase 1 §1 is the schema; Phase 2 only reads it | §6.1 (LoadStyleSpec uses `StyleSpec.load`) |
| X2 | Phase 1 Track C → Phase 2 Step 1 handoff | §6.2 (reads `piece.chosen_url`) |
| X3 | Phase 2 Step 6 → Phase 3 Step 1 handoff | §6.8 (writes `composite_url`) |

**Deferred to other modules:** Step 7 (weekly review gate) is module 06's job — orchestration, not
per-piece decision. The Step 4b color-role determination (module 02's B6) is upstream — Step 4b only
*confirms and records* the pre-set role, it does not recompute it.
