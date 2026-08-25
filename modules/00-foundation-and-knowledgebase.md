# Module 00 — Foundation, Repo Structure & Knowledge Base

> **You are building a Rails 8 application that runs an art-production and Etsy-listing pipeline.**
> This document is fully self-contained. Do not search the internet for the domain rules — every rule
> this module needs is written out below verbatim. Build exactly what is specified.

---

## Contract

**Depends on:** nothing. This is the first module.

**Provides (no other module may redefine these):**
- The Rails application skeleton and gem set
- The `knowledge_base/` directory layout and its file-format conventions
- The `piece_records` and `performance_snapshots` database tables
- `Workflow::PreflightCheck` (the git-clean guard)
- `KnowledgeBase::StyleSpec` / `KnowledgeBase::SceneSpec` loaders and their YAML format
- `KnowledgeBase::RuleSet` loader (generic YAML rule-file reader)
- `Steps::Base` (the base class every step in modules 01–05 inherits from)
- `config/step_registry.yml` (the canonical list of all 38 pipeline steps)

**Consumed by:** every subsequent module (01–07).

**Explicitly NOT in this module:** any domain rule content (frame materials, Etsy tags, etc.). Those
live in modules 01–05. This module builds the containers; later modules fill them.

---

## 1. Architectural decisions (do not deviate)

These were decided deliberately. If a decision looks unusual, it is intentional.

### 1.1 Knowledge lives in files, operational data lives in the database

- **Files (version-controlled, in `knowledge_base/`):** rule tables, prompt templates, style specs,
  scene specs. These change rarely, are edited by a human or by an AI assistant proposing a diff, and
  are reviewed before being merged. Git provides the version history, the audit trail, the validation
  gate (diff review), and rollback. **Do not build a database-backed rule editor, an admin CRUD UI,
  or a draft/publish state machine for rules.** Git already is that system.
- **Database:** `piece_records` (one row per piece produced) and `performance_snapshots` (Etsy metrics
  over time). This data accumulates automatically, is queried relationally, and has no meaningful diff.

### 1.2 Every run is stamped with the knowledge-base git SHA

A `PieceRecord` must record exactly which version of the rules produced it. Without this, performance
analysis later is guesswork. See §5.

### 1.3 Not every pipeline step is an LLM call

Steps fall into four mechanisms. The step's ownership tag describes *who owns the judgment*; the
mechanism describes *what code runs*. They are different things.

| Mechanism | What it is | Example |
|---|---|---|
| `:lookup` | Deterministic dictionary lookup against a rule YAML. **No LLM call.** | Frame material from Content Type + Mood |
| `:llm_vision` | Multimodal classification of a scene/art image, returns constrained JSON | Wall condition (plain vs. patterned) |
| `:llm_text` | Text generation/synthesis, returns constrained JSON | Etsy listing description |
| `:image_gen` | External image-generation API | Art generation |
| `:deterministic_tool` | Pixel math / compositing. **Never an LLM.** | Placing art in a scene at correct eye level |
| `:human` | Pipeline pauses; a person acts | Locking a style spec |

**Critical:** the majority of steps tagged `[AGENT-READY]` in this pipeline are `:lookup`, not LLM
calls. Sending a rule table to a model and asking it to read the table is slower, costs money, and
introduces a failure mode that a Ruby hash lookup does not have. Only use `:llm_vision` / `:llm_text`
where the step genuinely requires perception or language generation.

### 1.4 PostgreSQL, not SQLite

Chosen for `jsonb` columns and the aggregate queries module 07 needs over performance data.

---

## 2. Application setup

### 2.1 Create the app

```bash
rails new setthewall --database=postgresql --css=tailwind
cd setthewall
```

Requires Rails 8.x and Ruby 3.2+.

### 2.2 Gemfile additions

```ruby
# Gemfile

# LLM provider abstraction
gem "ruby_llm"
gem "ruby_llm-schema"

# Local env var loading
gem "dotenv-rails", groups: [:development, :test]

# HTTP for the image-generation and Etsy APIs
gem "faraday"

# Image compositing (Step 6) — deterministic, not an LLM
gem "ruby-vips"
```

`ruby-vips` requires the libvips system library:
- macOS: `brew install vips`
- Debian/Ubuntu: `sudo apt-get install libvips`

Then:

```bash
bundle install
bin/rails generate ruby_llm:install
bin/rails db:create
bin/rails db:migrate
bin/rails ruby_llm:load_models
```

> `ruby_llm:install` generates its own `Chat`/`Message`/`ToolCall` models and migrations. Leave them
> in place. This pipeline does not use conversational chat persistence for its steps, but the model
> registry (`ruby_llm:load_models`) is used for capability/pricing lookup.

### 2.3 API tokens (localhost)

Create `.env` in the project root. **Add `.env` to `.gitignore` immediately — before the first
commit.** Commit `.env.example` with empty values instead.

```bash
# .env
ANTHROPIC_API_KEY=
OPENAI_API_KEY=

# Image generation — set whichever provider you use (see module 03)
IMAGE_GEN_PROVIDER=
IMAGE_GEN_API_KEY=

# Etsy (see module 05)
ETSY_API_KEY=
ETSY_API_SECRET=
ETSY_SHOP_ID=
ETSY_OAUTH_TOKEN=
```

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  config.openai_api_key    = ENV.fetch("OPENAI_API_KEY", nil)
  config.request_timeout   = 180
end
```

```ruby
# config/initializers/pipeline.rb
module Pipeline
  # Default models per mechanism. Override per-step in the step class if needed.
  VISION_MODEL = ENV.fetch("PIPELINE_VISION_MODEL", "claude-sonnet-5")
  TEXT_MODEL   = ENV.fetch("PIPELINE_TEXT_MODEL",   "claude-sonnet-5")

  # Root of the version-controlled knowledge base.
  KB_ROOT = Rails.root.join("knowledge_base")
end
```

---

## 3. Directory structure

Create this exact layout. Later modules add files inside it but must not change its shape.

```
setthewall/
├── knowledge_base/              # VERSION-CONTROLLED KNOWLEDGE. Edited by humans/AI, reviewed via git diff.
│   ├── README.md                # Provenance + editing conventions (content in §4.4 below)
│   ├── rules/                   # Rule tables as YAML. Modules 02, 04, 05 populate.
│   │   └── .keep
│   ├── prompts/                 # LLM prompt templates as Markdown. Modules 01–05 populate.
│   │   └── .keep
│   ├── style_specs/             # One YAML per style. Written by modules 01 & 02 (Track A & B).
│   │   └── .keep
│   └── scene_templates/         # Scene mockup metadata + measurements. Module 04 uses for compositing.
│       └── .keep
│
├── docs/
│   └── source_knowledge_base/   # UNTOUCHED copies of the 3 original phase docs. Audit trail only.
│       ├── setthewall-phase1-style-spec-determination.md
│       ├── setthewall-phase2-decor-system.md
│       └── setthewall-phase3-module1-etsy-listing.md
│
├── app/
│   ├── models/
│   │   ├── piece_record.rb
│   │   └── performance_snapshot.rb
│   ├── knowledge_base/          # Loaders that read knowledge_base/*. NOT ActiveRecord.
│   │   ├── style_spec.rb
│   │   ├── scene_spec.rb
│   │   └── rule_set.rb
│   ├── steps/                   # One class per pipeline step. Modules 01–05 populate.
│   │   ├── base.rb
│   │   ├── track_a/
│   │   ├── track_b/
│   │   ├── track_c/
│   │   ├── phase2/
│   │   └── phase3/
│   ├── llm/
│   │   └── schemas/             # RubyLLM::Schema classes. Modules 01–05 populate.
│   └── workflow/
│       └── preflight_check.rb
│
└── config/
    └── step_registry.yml        # Canonical list of all 38 steps (content in §6)
```

**Note on `docs/source_knowledge_base/`:** copy the three original phase docs there verbatim. They are
*not* read at runtime and *not* parsed by any code. They exist so that a future reader looking at a
rule file can trace it back to its origin. Every rule YAML carries a citation comment pointing here.

---

## 4. Knowledge-base file format conventions

### 4.1 Rule files (`knowledge_base/rules/*.yml`)

Every rule file must follow this shape:

```yaml
# ---
# source: Phase 2 §2.3 — Match vs. contrast
# citation: how_to_arrange_pictures / at_home_with_pictures, p. 20-21, p. 61
# doc: docs/source_knowledge_base/setthewall-phase2-decor-system.md
# last_verified: 2026-08-24
# ---

meta:
  source: "Phase 2 §2.3"
  citation: "p. 20-21, p. 61"
  volatility: static        # static | live  — see §4.3

rules:
  # ... actual rule content, shape varies per rule file
```

**Every rule file must carry `meta.source`, `meta.citation`, and `meta.volatility`.** A rule with no
citation is not permitted — provenance is the point of this knowledge base.

### 4.2 Prompt files (`knowledge_base/prompts/*.md`)

Plain Markdown. Contains only what the model needs: the task, the decision criteria, any default/
fallback rule, and the required output shape. **Strip citations and doc scaffolding** — a page number
helps a human auditor and does nothing for the model at inference time.

Interpolation uses Ruby `format`-style named placeholders: `%{mood}`, `%{content_type}`.

### 4.3 `volatility` — static vs. live

| Value | Meaning | Applies to |
|---|---|---|
| `static` | Source is a fixed published book. Will not change. | All Phase 2 decoration rules |
| `live` | Source is a third-party system that changes without notice. Needs periodic re-verification. | All Phase 3 Etsy rules |

This distinction matters. Etsy's own documentation states its search algorithm changes regularly, so
Phase 3's rule files must be re-checked against Etsy's current Seller Handbook periodically. The
arrangement-book rules behind Phase 2 do not have this problem. Module 07 uses `volatility: live` to
flag which rule files need a staleness review.

### 4.4 `knowledge_base/README.md`

Create this file with exactly this content:

```markdown
# Knowledge Base

This directory is the live source of truth for every rule the pipeline applies. It is
version-controlled; git history is the audit trail and `git diff` review is the validation gate.

## Editing rules

1. Edit the YAML/Markdown files here directly — never edit generated copies elsewhere.
2. Every rule must carry `meta.source` and `meta.citation`. Uncited rules are not permitted.
3. Commit before running the pipeline. `Workflow::PreflightCheck` will refuse to run a
   production pipeline against uncommitted knowledge-base changes.
4. `docs/source_knowledge_base/` holds untouched copies of the original phase documents.
   They are the provenance trail. Do not edit them; do not read them at runtime.

## Provenance notes

- **Arrangement-book citations carry page numbers.** The source scan has them embedded.
- **Business-strategy citations use chapter titles, not page numbers.** Those source PDFs do
  not expose reliable page numbers. This is a difference in source format, not a lower
  sourcing standard.
- **Page 56 of the arrangement book carries OCR noise.** Any rule tracing to p. 56 should be
  treated as directionally reliable rather than a verbatim quote. Where a rule needed p. 56's
  content, cleaner passages elsewhere in the same book were used instead.
- **Etsy rules (`volatility: live`) describe a system Etsy controls and changes.** Re-verify
  against the current Etsy Seller Handbook periodically. Do not treat them as permanently
  accurate the way the arrangement-book rules can be.
```

---

## 5. `Workflow::PreflightCheck` — the git-clean guard

The pipeline must not run a production job against uncommitted knowledge-base edits, because the
resulting `PieceRecord` would be stamped with a SHA that does not describe the rules actually used.

```ruby
# app/workflow/preflight_check.rb
module Workflow
  class DirtyKnowledgeBaseError < StandardError; end

  class PreflightCheck
    WATCHED_PATHS = %w[knowledge_base/].freeze

    Result = Struct.new(:kb_version, :dirty, keyword_init: true)

    # Returns a Result. Raises unless allow_dirty is true and the tree is dirty.
    #
    #   allow_dirty: false (default) — production run. Refuses on any uncommitted change.
    #   allow_dirty: true            — local iteration. Stamps "dirty:<sha>" so the run is
    #                                  identifiable as untrustworthy in later analysis.
    def self.call!(allow_dirty: false)
      status = `git status --porcelain #{WATCHED_PATHS.join(' ')}`.strip
      sha    = `git rev-parse HEAD`.strip

      raise DirtyKnowledgeBaseError, "git not available or not a repo" if sha.empty?

      if status.empty?
        Result.new(kb_version: sha, dirty: false)
      elsif allow_dirty
        Result.new(kb_version: "dirty:#{sha}", dirty: true)
      else
        raise DirtyKnowledgeBaseError, <<~MSG
          Uncommitted changes in the knowledge base. Commit before running:

          #{status}

          To run anyway for local iteration, pass allow_dirty: true. Runs made this way are
          stamped "dirty:<sha>" and should not be used for performance analysis.
        MSG
      end
    end
  end
end
```

**Scope note:** the check watches `knowledge_base/` only, not the whole repo. An unrelated in-progress
code change should not block a pipeline run — only knowledge changes affect reproducibility.

---

## 6. `config/step_registry.yml` — all 38 steps

This is the canonical registry. Module 06 orchestrates from it. Modules 01–05 implement the classes it
names. Create it now, in full, exactly as below.

```yaml
# Canonical registry of every pipeline step.
# ownership: verbatim from the source phase docs — do not paraphrase.
# mechanism: what code actually runs (see module 00 §1.3)
# cadence:   per_style | per_scene | daily | weekly

phase_1:
  track_a:
    cadence: per_style
    steps:
      - id: A0
        title: "Validate the style is worth pursuing"
        ownership: "[AGENT-READY for the research — human confirms the go/no-go]"
        mechanism: llm_text
        human_gate: true
        klass: "Steps::TrackA::ValidateStyle"
      - id: A1
        title: "Build a reference set"
        ownership: "[AGENT-ASSISTED — human curates]"
        mechanism: llm_text
        human_gate: true
        klass: "Steps::TrackA::BuildReferenceSet"
      - id: A2
        title: "Sort into Mood"
        ownership: "[AGENT-ASSISTED — human confirms]"
        mechanism: llm_vision
        human_gate: true
        klass: "Steps::TrackA::SortMood"
      - id: A3
        title: "Sort into Content Type"
        ownership: "[AGENT-ASSISTED — human confirms]"
        mechanism: llm_vision
        human_gate: true
        klass: "Steps::TrackA::SortContentType"
      - id: A4
        title: "Sort into Frame Form"
        ownership: "[AGENT-ASSISTED — human confirms]"
        mechanism: llm_vision
        human_gate: true
        klass: "Steps::TrackA::SortFrameForm"
      - id: A5
        title: "Lock the style-level entry"
        ownership: "[HUMAN ONLY]"
        mechanism: human
        human_gate: true
        klass: "Steps::TrackA::LockStyleEntry"

  track_b:
    cadence: per_scene
    steps:
      - id: B0
        title: "Confirm the scene template is fixed"
        ownership: "[HUMAN ONLY]"
        mechanism: human
        human_gate: true
        klass: "Steps::TrackB::ConfirmSceneTemplate"
      - id: B1
        title: "Wall Condition"
        ownership: "[AGENT-READY]"
        mechanism: llm_vision
        human_gate: false
        klass: "Steps::TrackB::WallCondition"
      - id: B2
        title: "Furniture Weight"
        ownership: "[AGENT-READY]"
        mechanism: llm_vision
        human_gate: false
        klass: "Steps::TrackB::FurnitureWeight"
      - id: B3
        title: "Room Type"
        ownership: "[AGENT-READY]"
        mechanism: llm_vision
        human_gate: false
        klass: "Steps::TrackB::RoomType"
      - id: B4
        title: "Room Shape/Proportion"
        ownership: "[AGENT-READY]"
        mechanism: llm_vision
        human_gate: false
        klass: "Steps::TrackB::RoomShape"
      - id: B5
        title: "Space Math"
        ownership: "[AGENT-READY]"
        mechanism: llm_vision
        human_gate: false
        klass: "Steps::TrackB::SpaceMath"
      - id: B6
        title: "Color Role"
        ownership: "[AGENT-READY for steps 1 & 3 — human confirms the override call in step 2]"
        mechanism: llm_vision
        human_gate: true
        klass: "Steps::TrackB::ColorRole"
      - id: B7
        title: "Lock the per-scene entry"
        ownership: "[HUMAN ONLY]"
        mechanism: human
        human_gate: true
        klass: "Steps::TrackB::LockSceneEntry"

  track_c:
    cadence: daily
    steps:
      - id: C1
        title: "Generate art"
        ownership: "[AGENT-ASSISTED — human enforces batch cap]"
        mechanism: image_gen
        human_gate: false
        klass: "Steps::TrackC::GenerateArt"
      - id: C2
        title: "Cull to finalists"
        ownership: "[AGENT-ASSISTED — human makes final pick]"
        mechanism: human
        human_gate: true
        klass: "Steps::TrackC::CullToFinalists"

phase_2:
  cadence: daily
  steps:
    - id: P2_0
      title: "Load the style spec"
      ownership: "[HUMAN ONLY]"
      mechanism: human
      cadence: weekly
      human_gate: true
      klass: "Steps::Phase2::LoadStyleSpec"
    - id: P2_1
      title: "Measure the scene, choose the placement branch"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      klass: "Steps::Phase2::MeasureScene"
    - id: P2_2a
      title: "Single piece: confirm focal treatment"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      branch_of: P2_1
      klass: "Steps::Phase2::SingleFocalTreatment"
    - id: P2_2b
      title: "Multi-piece set: grouping form and count"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      branch_of: P2_1
      klass: "Steps::Phase2::SetGroupingAndCount"
    - id: P2_2c
      title: "Split-wall: zone the wall"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      branch_of: P2_1
      klass: "Steps::Phase2::SplitWallZoning"
    - id: P2_2d
      title: "Architectural nook: fit to the space"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      branch_of: P2_1
      klass: "Steps::Phase2::NookFit"
    - id: P2_2e
      title: "Surface/propped display: height and lean"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      branch_of: P2_1
      klass: "Steps::Phase2::SurfaceDisplay"
    - id: P2_3
      title: "Unify by theme"
      ownership: "[AGENT-ASSISTED — vision check, human confirms]"
      mechanism: llm_vision
      human_gate: true
      conditional: "only when branch produces a multi-piece set"
      klass: "Steps::Phase2::UnifyByTheme"
    - id: P2_4
      title: "Assign frame material and contour"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      klass: "Steps::Phase2::AssignFrame"
    - id: P2_4b
      title: "Color function check"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      klass: "Steps::Phase2::ColorFunctionCheck"
    - id: P2_5
      title: "Check weight balance"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      klass: "Steps::Phase2::WeightBalance"
    - id: P2_6
      title: "Composite into the scene"
      ownership: "[NOT AN AGENT/LLM TASK — deterministic template tool required]"
      mechanism: deterministic_tool
      human_gate: false
      klass: "Steps::Phase2::Composite"
    - id: P2_7
      title: "Weekly review gate"
      ownership: "[HUMAN ONLY — agent may summarize data, not decide]"
      mechanism: human
      cadence: weekly
      human_gate: true
      klass: "Steps::Phase2::WeeklyReview"

phase_3_module_1:
  cadence: daily
  steps:
    - id: P3_1
      title: "Pull inputs from Phase 2"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      klass: "Steps::Phase3::PullInputs"
    - id: P3_1b
      title: "Generate the missing photo types"
      ownership: "[AGENT-ASSISTED — human confirms]"
      mechanism: image_gen
      human_gate: true
      klass: "Steps::Phase3::GeneratePhotoTypes"
    - id: P3_2
      title: "Select and order photos"
      ownership: "[AGENT-ASSISTED — human confirms hero shot]"
      mechanism: llm_vision
      human_gate: true
      klass: "Steps::Phase3::SelectAndOrderPhotos"
    - id: P3_3
      title: "Draft title"
      ownership: "[AGENT-READY]"
      mechanism: llm_text
      human_gate: false
      klass: "Steps::Phase3::DraftTitle"
    - id: P3_4
      title: "Fill tags"
      ownership: "[AGENT-READY]"
      mechanism: llm_text
      human_gate: false
      klass: "Steps::Phase3::FillTags"
    - id: P3_5
      title: "Fill attributes and category"
      ownership: "[AGENT-READY]"
      mechanism: lookup
      human_gate: false
      klass: "Steps::Phase3::FillAttributes"
    - id: P3_6
      title: "Write description"
      ownership: "[AGENT-ASSISTED — human confirms tone]"
      mechanism: llm_text
      human_gate: true
      klass: "Steps::Phase3::WriteDescription"
    - id: P3_7
      title: "Set shipping and return policy"
      ownership: "[HUMAN ONLY — pricing/policy strategy]"
      mechanism: human
      human_gate: true
      klass: "Steps::Phase3::ShippingAndReturns"
    - id: P3_8
      title: "Publish and log baseline"
      ownership: "[AGENT-ASSISTED]"
      mechanism: lookup
      human_gate: false
      klass: "Steps::Phase3::PublishAndLog"
```

**Counts to verify after creating this file: 16 Phase 1 steps, 13 Phase 2 steps, 9 Phase 3 steps —
38 total. 17 steps have `human_gate: true` — A0, A1, A2, A3, A4, A5, B0, B6, B7, C2, P2_0, P2_3, P2_7,
P3_1b, P3_2, P3_6, P3_7.**

---

## 7. Style Spec & Scene Spec — file format

This is the schema the whole pipeline reads. Phase 1 Tracks A and B *determine* these values; every
later phase only ever *reads* them. **No module after 01/02 may infer or re-derive a spec value.**

### 7.1 Format

One file per style: `knowledge_base/style_specs/<style_slug>.yml`

```yaml
# knowledge_base/style_specs/japandi-v1.yml
slug: japandi-v1
name: "Japandi"
locked_at: "2026-08-24"

# --- Style-level axes: set ONCE per style (Phase 1 Track A) ---
style_level:
  mood: calm_ordered              # calm_ordered | bold_active
  content_type: minimalist_modern # detailed_representational | minimalist_modern | portrait_still_life
  frame_form: angular             # angular | rounded

# --- Per-scene axes: set ONCE per scene template (Phase 1 Track B) ---
scenes:
  behind_sofa_light_neutral:
    name: "Behind sofa — light neutral"
    template_ref: scene_templates/behind_sofa_light_neutral.yml
    locked_at: "2026-08-24"
    axes:
      wall_condition: neutral       # neutral | busy
      furniture_weight: light       # light | dark
      room_type: seated_room        # seated_room | hallway | no_furniture_wall
      room_shape: none              # narrow | low_ceilinged | small_closed_in | none
      space_math: single            # single | set | split_wall | nook | surface
      color_role: line_only         # accent_highlighter | color_burst | unifier | saturator | line_only
```

### 7.2 The nine axes and what each controls

Reproduce this table as a comment block at the top of `app/knowledge_base/style_spec.rb`.

**Style-level (3 axes, set once per style):**

| Axis | Values | Controls |
|---|---|---|
| `mood` | `calm_ordered` / `bold_active` | frame material finish, frame form, color pairing (complementary vs. tension), arrangement mood-layer, focal intensity |
| `content_type` | `detailed_representational` / `minimalist_modern` / `portrait_still_life` | frame material category, frame contour, matting technique trigger for close framing |
| `frame_form` | `angular` / `rounded` | frame perimeter shape |

**Per-scene (6 axes, set once per scene template):**

| Axis | Values | Controls |
|---|---|---|
| `wall_condition` | `neutral` / `busy` | match vs. contrast frame choice |
| `furniture_weight` | `light` / `dark` | weight-balance check |
| `room_type` | `seated_room` / `hallway` / `no_furniture_wall` | which eye-level formula applies |
| `room_shape` | `narrow` / `low_ceilinged` / `small_closed_in` / `none` | space tips — content line orientation |
| `space_math` | `single` / `set` / `split_wall` / `nook` / `surface` | placement branch |
| `color_role` | `accent_highlighter` / `color_burst` / `unifier` / `saturator` / `line_only` | mat intensity, accessory/wall echo, saturation technique |

### 7.3 Completeness rule

**A style is complete when all three style-level axes are set, and every scene template under it has
values for all six per-scene axes. No blanks.** This must be enforced in code, not left to discipline:

```ruby
# app/knowledge_base/style_spec.rb
module KnowledgeBase
  class IncompleteSpecError < StandardError; end

  class StyleSpec
    STYLE_LEVEL_AXES = %i[mood content_type frame_form].freeze
    SCENE_AXES = %i[wall_condition furniture_weight room_type room_shape space_math color_role].freeze

    ALLOWED = {
      mood:             %w[calm_ordered bold_active],
      content_type:     %w[detailed_representational minimalist_modern portrait_still_life],
      frame_form:       %w[angular rounded],
      wall_condition:   %w[neutral busy],
      furniture_weight: %w[light dark],
      room_type:        %w[seated_room hallway no_furniture_wall],
      room_shape:       %w[narrow low_ceilinged small_closed_in none],
      space_math:       %w[single set split_wall nook surface],
      color_role:       %w[accent_highlighter color_burst unifier saturator line_only]
    }.freeze

    attr_reader :slug, :name, :style_level, :scenes, :path

    def self.load(slug)
      path = Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml")
      raise IncompleteSpecError, "No style spec at #{path}" unless path.exist?

      new(YAML.safe_load_file(path, permitted_classes: [Date]), path)
    end

    def self.all
      Dir.glob(Pipeline::KB_ROOT.join("style_specs", "*.yml")).map do |f|
        load(File.basename(f, ".yml"))
      end
    end

    def initialize(raw, path)
      @path        = path
      @slug        = raw.fetch("slug")
      @name        = raw.fetch("name")
      @style_level = raw.fetch("style_level").symbolize_keys
      @scenes      = raw.fetch("scenes", {})
    end

    def scene(scene_id)
      raw = scenes.fetch(scene_id.to_s) do
        raise IncompleteSpecError, "Scene '#{scene_id}' not found in #{slug}"
      end
      SceneSpec.new(scene_id, raw, self)
    end

    def scene_ids = scenes.keys

    # Raises unless every axis is present AND holds an allowed value.
    def validate!
      STYLE_LEVEL_AXES.each do |axis|
        value = style_level[axis]
        raise IncompleteSpecError, "#{slug}: style_level.#{axis} is blank" if value.blank?
        unless ALLOWED[axis].include?(value.to_s)
          raise IncompleteSpecError, "#{slug}: style_level.#{axis}='#{value}' not in #{ALLOWED[axis]}"
        end
      end

      raise IncompleteSpecError, "#{slug}: no scene templates defined" if scenes.empty?
      scene_ids.each { |id| scene(id).validate! }

      true
    end
  end
end
```

```ruby
# app/knowledge_base/scene_spec.rb
module KnowledgeBase
  class SceneSpec
    attr_reader :id, :name, :axes, :template_ref, :style_spec

    def initialize(id, raw, style_spec)
      @id           = id.to_s
      @style_spec   = style_spec
      @name         = raw.fetch("name", id.to_s)
      @template_ref = raw["template_ref"]
      @axes         = raw.fetch("axes", {}).symbolize_keys
    end

    StyleSpec::SCENE_AXES.each do |axis|
      define_method(axis) { axes[axis] }
    end

    def validate!
      StyleSpec::SCENE_AXES.each do |axis|
        value = axes[axis]
        if value.blank?
          raise IncompleteSpecError, "#{style_spec.slug}/#{id}: axes.#{axis} is blank"
        end
        unless StyleSpec::ALLOWED[axis].include?(value.to_s)
          raise IncompleteSpecError,
                "#{style_spec.slug}/#{id}: axes.#{axis}='#{value}' not in #{StyleSpec::ALLOWED[axis]}"
        end
      end
      true
    end
  end
end
```

---

## 8. `KnowledgeBase::RuleSet` — the generic rule loader

Every rule YAML in `knowledge_base/rules/` is read through this. Modules 02, 04, 05 use it rather than
reading YAML directly.

```ruby
# app/knowledge_base/rule_set.rb
module KnowledgeBase
  class RuleNotFoundError < StandardError; end
  class MissingCitationError < StandardError; end

  class RuleSet
    attr_reader :name, :meta, :rules

    def self.load(name)
      @cache ||= {}
      @cache[name] ||= begin
        path = Pipeline::KB_ROOT.join("rules", "#{name}.yml")
        raise RuleNotFoundError, "No rule file at #{path}" unless path.exist?

        raw = YAML.safe_load_file(path, permitted_classes: [Date])
        new(name, raw)
      end
    end

    def self.reset_cache! = @cache = nil

    def initialize(name, raw)
      @name  = name
      @meta  = raw.fetch("meta", {})
      @rules = raw.fetch("rules", {})

      if @meta["citation"].blank? || @meta["source"].blank?
        raise MissingCitationError,
              "Rule file '#{name}' is missing meta.source or meta.citation. " \
              "Every rule must carry provenance."
      end
    end

    # Nested lookup with a clear error rather than a silent nil.
    #   RuleSet.load("frame_material").fetch("minimalist_modern", "calm_ordered")
    def fetch(*keys)
      keys.map(&:to_s).reduce(rules) do |node, key|
        unless node.is_a?(Hash) && node.key?(key)
          raise RuleNotFoundError, "#{name}: no rule at path #{keys.inspect} (failed at '#{key}')"
        end
        node[key]
      end
    end

    def live? = meta["volatility"].to_s == "live"
  end
end
```

**Rationale for raising instead of returning nil:** a missing rule must fail loudly. A silent `nil`
propagating into a frame decision produces a plausible-looking but ungrounded output, which is the
exact failure this knowledge base exists to prevent.

---

## 9. Database schema

### 9.1 `piece_records`

```ruby
# db/migrate/XXXXXX_create_piece_records.rb
class CreatePieceRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :piece_records do |t|
      # --- Knowledge-base linkage (files, not FKs — see module 00 §1.1) ---
      t.string :style_spec_slug, null: false
      t.string :scene_spec_id,   null: false
      t.string :kb_version,      null: false   # git SHA, or "dirty:<sha>" for local runs

      # --- Style Spec values, denormalized at run time ---
      # Copied in so a piece stays interpretable even if the spec file later changes.
      t.string :mood
      t.string :content_type
      t.string :frame_form
      t.string :wall_condition
      t.string :furniture_weight
      t.string :room_type
      t.string :room_shape
      t.string :space_math
      t.string :color_role

      # --- Phase 1 Track C ---
      t.integer :batch_count
      t.jsonb   :candidate_urls, null: false, default: []
      t.jsonb   :finalist_urls,  null: false, default: []
      t.string  :chosen_url

      # --- Phase 2 ---
      t.string  :placement_branch          # single | set | split_wall | nook | surface
      t.string  :frame_material_category
      t.string  :frame_material_finish
      t.string  :frame_contour
      t.string  :matting_technique
      t.string  :mat_intensity
      t.string  :arrangement_form
      t.integer :piece_count
      t.string  :anchor_piece_ref
      t.boolean :weight_balance_pass
      t.jsonb   :composite_measurements, null: false, default: {}
      t.string  :composite_url

      # --- Phase 3 ---
      t.jsonb   :photos, null: false, default: {}   # {studio:, lifestyle:, detail:, scale:, group:, packaging:}
      t.jsonb   :photo_order, null: false, default: []
      t.string  :listing_title
      t.jsonb   :listing_tags, null: false, default: []
      t.jsonb   :listing_attributes, null: false, default: {}
      t.string  :listing_category
      t.text    :listing_description
      t.string  :etsy_listing_id
      t.datetime :published_at

      # --- Orchestration ---
      t.string  :status, null: false, default: "pending"
      t.string  :current_step
      t.jsonb   :step_log, null: false, default: []   # append-only audit of every step run
      t.text    :last_error

      t.timestamps
    end

    add_index :piece_records, :status
    add_index :piece_records, :kb_version
    add_index :piece_records, :etsy_listing_id, unique: true
    add_index :piece_records, [:style_spec_slug, :scene_spec_id]
  end
end
```

### 9.2 `performance_snapshots`

```ruby
# db/migrate/XXXXXX_create_performance_snapshots.rb
class CreatePerformanceSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :performance_snapshots do |t|
      t.references :piece_record, null: false, foreign_key: true
      t.date    :captured_on, null: false
      t.integer :views,     default: 0
      t.integer :favorites, default: 0
      t.integer :orders,    default: 0
      t.decimal :revenue, precision: 10, scale: 2, default: 0
      t.jsonb   :search_terms, null: false, default: []  # from Etsy Shop Stats
      t.jsonb   :raw, null: false, default: {}           # untouched API payload
      t.timestamps
    end

    add_index :performance_snapshots, [:piece_record_id, :captured_on], unique: true
  end
end
```

> **Why a snapshot table rather than counter columns on `piece_records`:** module 07 needs to compare
> performance *over time* and against `kb_version`. Overwriting a single `views` column destroys the
> history that analysis depends on.

### 9.3 Models

```ruby
# app/models/piece_record.rb
class PieceRecord < ApplicationRecord
  has_many :performance_snapshots, dependent: :destroy

  STATUSES = %w[pending running awaiting_human complete failed].freeze

  validates :style_spec_slug, :scene_spec_id, :kb_version, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :awaiting_human, -> { where(status: "awaiting_human") }
  scope :published,      -> { where.not(published_at: nil) }
  scope :trustworthy,    -> { where.not("kb_version LIKE 'dirty:%'") }

  def style_spec = KnowledgeBase::StyleSpec.load(style_spec_slug)
  def scene_spec = style_spec.scene(scene_spec_id)

  def dirty_run? = kb_version.to_s.start_with?("dirty:")

  # Copy the nine axis values in at creation time.
  def apply_spec!(spec, scene)
    assign_attributes(
      mood: spec.style_level[:mood],
      content_type: spec.style_level[:content_type],
      frame_form: spec.style_level[:frame_form],
      wall_condition: scene.wall_condition,
      furniture_weight: scene.furniture_weight,
      room_type: scene.room_type,
      room_shape: scene.room_shape,
      space_math: scene.space_math,
      color_role: scene.color_role
    )
  end

  def log_step!(step_id:, mechanism:, outcome:, detail: {})
    self.step_log = step_log + [{
      step_id:, mechanism:, outcome:, detail:,
      at: Time.current.iso8601
    }]
    save!
  end
end
```

```ruby
# app/models/performance_snapshot.rb
class PerformanceSnapshot < ApplicationRecord
  belongs_to :piece_record

  validates :captured_on, presence: true
  validates :captured_on, uniqueness: { scope: :piece_record_id }

  def conversion_rate = views.to_i.zero? ? 0.0 : (orders.to_f / views)
end
```

---

## 10. `Steps::Base` — the base class for all 38 steps

Every step class in modules 01–05 inherits from this. It enforces the uniform contract: take a
`PieceRecord` (or a spec context), do work, return a `StepResult`, log what happened.

```ruby
# app/steps/base.rb
module Steps
  StepResult = Struct.new(:status, :data, :message, keyword_init: true) do
    def ok?             = status == :ok
    def awaiting_human? = status == :awaiting_human
    def failed?         = status == :failed
  end

  class Base
    class << self
      # Every subclass declares these. Values must match config/step_registry.yml.
      attr_reader :step_id, :mechanism, :ownership

      def step(id:, mechanism:, ownership:)
        @step_id   = id
        @mechanism = mechanism
        @ownership = ownership
      end
    end

    attr_reader :piece, :context

    def initialize(piece:, context: {})
      @piece   = piece
      @context = context
    end

    def self.call(...) = new(...).call

    def call
      result = perform
      piece&.log_step!(
        step_id: self.class.step_id,
        mechanism: self.class.mechanism,
        outcome: result.status,
        detail: result.data || {}
      )
      result
    rescue StandardError => e
      piece&.update(status: "failed", last_error: "#{self.class.step_id}: #{e.message}")
      raise
    end

    private

    # Subclasses implement this and return a StepResult.
    def perform = raise NotImplementedError

    def ok(data = {}, message: nil)  = StepResult.new(status: :ok, data:, message:)
    def needs_human(reason, data = {}) = StepResult.new(status: :awaiting_human, data:, message: reason)
    def fail_step(reason, data = {})   = StepResult.new(status: :failed, data:, message: reason)

    def rules(name) = KnowledgeBase::RuleSet.load(name)

    def prompt(name, **vars)
      template = Pipeline::KB_ROOT.join("prompts", "#{name}.md").read
      format(template, **vars)
    end

    def spec  = piece.style_spec
    def scene = piece.scene_spec
  end
end
```

**`needs_human` is how every `[HUMAN ONLY]` and `[AGENT-ASSISTED — human confirms]` gate is
implemented.** A step returning `:awaiting_human` sets `PieceRecord#status = "awaiting_human"` and the
orchestrator (module 06) stops; nothing downstream runs until a person acts.

---

## 11. Verification for this module

Run these before considering module 00 done:

```bash
# 1. App boots
bin/rails runner 'puts "ok"'

# 2. Migrations applied, tables exist with expected column counts
bin/rails runner 'puts PieceRecord.column_names.size'          # expect 44
bin/rails runner 'puts PerformanceSnapshot.column_names.size'  # expect 11

# 3. Step registry parses and has the right shape
bin/rails runner '
  reg = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  p1 = reg["phase_1"].values.sum { |t| t["steps"].size }
  p2 = reg["phase_2"]["steps"].size
  p3 = reg["phase_3_module_1"]["steps"].size
  puts "phase1=#{p1} phase2=#{p2} phase3=#{p3} total=#{p1+p2+p3}"
  gates = reg.to_s.scan(/human_gate: true|"human_gate"=>true/).size
  puts "human_gates=#{gates}"
'
# expect: phase1=16 phase2=13 phase3=9 total=38
# expect: human_gates=17

# 4. Preflight guard works
bin/rails runner 'p Workflow::PreflightCheck.call!(allow_dirty: true)'

# 5. Knowledge base directories exist
ls knowledge_base/rules knowledge_base/prompts knowledge_base/style_specs knowledge_base/scene_templates

# 6. Source docs copied for provenance
ls docs/source_knowledge_base/   # expect 3 files

# 7. .env is gitignored
git check-ignore .env && echo "gitignored ok"
```

**Also verify by hand:**
- `knowledge_base/README.md` exists with the provenance notes from §4.4.
- `RuleSet` raises `MissingCitationError` for a rule file with no `meta.citation`. Test with a
  throwaway file, then delete it.
- `StyleSpec#validate!` raises on a blank axis and on an out-of-range value.

---

## 12. Manifest coverage

This module covers these items from `00-EXTRACTION-MANIFEST.md`:

| ID | Item | Where |
|---|---|---|
| X1 | Phase 1 §1 is the schema; later phases only read it | §7, `StyleSpec` |
| P1-P6 | Completeness rule — 3 style-level + 6 per-scene, no blanks | §7.3 `validate!` |
| P1-P3 | OCR caveat on p. 56 | §4.4 `knowledge_base/README.md` |
| — | Nine-axis definition table (P1-T1, P1-T2) | §7.2 |
| — | All 38 steps + ownership tags, verbatim | §6 `step_registry.yml` |
| — | Human-gate flags (15 gates) | §6, implemented via `needs_human` in §10 |

**Not covered here (belongs to later modules):** every domain rule table, every prompt body, all
borderline-default logic, all step implementations.
