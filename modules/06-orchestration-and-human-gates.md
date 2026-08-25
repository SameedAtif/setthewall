# Module 06 — Orchestration, State Machine & Human Gates

> **Self-contained.** No new domain rules in this module — orchestration only. The 17 human gates
> named in module 04 §7's cross-pipeline rollup are all implemented as pause states on
> `PieceRecord.status`, driven by a state machine and surfaced in a minimal Rails UI.

---

## Contract

**Depends on:** module 00 (`PieceRecord`, `Steps::Base`, `step_registry.yml`,
`Workflow::PreflightCheck`), modules 01–05 (every step class named in the registry).

**Provides:**
- `app/services/workflow/pipeline_run.rb` — the top-level entrypoint that starts a piece through
  the full daily pipeline
- `app/services/workflow/step_dispatcher.rb` — the one code path that invokes any step class
- `app/services/workflow/status_machine.rb` — the `PieceRecord.status` state machine
- Solid Queue jobs (`ProcessPieceJob`, `ResumePieceJob`) — the async runners
- `HumanGate` model + migration — tracks each individual pause point per piece with the reviewer's
  decision
- `HumanReviewsController` + `ReviewsController` — the minimal review UI (index of awaiting pieces,
  per-piece review + approve/reject/edit)
- `lib/tasks/pipeline.rake` — CLI entrypoints (`pipeline:daily`, `pipeline:track_a`,
  `pipeline:track_b`, `pipeline:resume`)

**Consumed by:** module 07 (evolution loop reads `HumanGate` records to see reviewer decisions).

**Must not:** implement any domain rule (modules 01–05 own those), define step classes (they exist
already), change the `piece_records` schema (module 00 owns it — this module adds a sibling table
for gate audit but does not modify the piece row shape).

---

## 1. Design decisions

Four decisions shape everything below.

### 1.1 One dispatcher, no per-step orchestration code

Every step is called through `Workflow::StepDispatcher.call(step_id:, piece:, context:)`. The
dispatcher reads the registry, resolves the class, invokes it, and interprets the `StepResult`. No
job class, controller, or rake task ever calls `Steps::Phase2::AssignFrame.call(...)` directly.

Why: 38 steps, 5 phases, three cadences (per-style, per-scene, daily). The alternative is 38
scattered call sites, each with slightly different error handling. One dispatcher means one place
that knows how to turn a `StepResult.awaiting_human?` into a status change, one place that logs to
`step_log`, one place that catches `Search::NoSearchPerformedError` / `Etsy::ApiError` /
`Compositor::TemplateError` / `KnowledgeBase::IncompleteSpecError` and turns them into a
`fail_step`.

### 1.2 The state machine is on `PieceRecord.status`, not a separate column

`PieceRecord.status` was defined in module 00 as a string with values `pending | running |
awaiting_human | complete | failed`. Module 06 turns those into a real state machine — with
`current_step` naming *which* step is running or awaiting, and a new `HumanGate` sibling table
recording *which* gate the reviewer acted on. No new column on `piece_records`, no new statuses.

Why: adding a state column that shadows an existing one is exactly the kind of change that
silently drifts. The status field module 00 already committed to is expressive enough — this
module just formalises the transitions.

### 1.3 Solid Queue, not Sidekiq

Rails 8's default is Solid Queue (backed by the database). The pipeline is low-volume — a handful
of pieces per day, each with 15–20 steps. Solid Queue is fine for that and avoids running a
separate Redis process on your localhost. If volume ever justifies switching, the swap is
straightforward: jobs inherit from `ApplicationJob`, not from queue-specific base classes.

### 1.4 Review UI is deliberately minimal

Not a general admin interface. It's a task list (pieces awaiting your attention), a per-piece
review page (what the step returned, what you'd approve/reject/edit), and nothing else. The
principle from *This Is Marketing* — the tool should do one thing well — applies to the tool that
runs the tool. It's easier to expand than to strip back.

---

## 2. `HumanGate` table

One row per pause. This gives module 07 an audit trail (reviewer decision + time + notes) without
needing to reconstruct anything from `step_log`.

```ruby
# db/migrate/XXXXXX_create_human_gates.rb
class CreateHumanGates < ActiveRecord::Migration[8.0]
  def change
    create_table :human_gates do |t|
      t.references :piece_record, null: false, foreign_key: true
      t.string     :step_id,   null: false     # e.g. "P3_2", "A5", "C2"
      t.string     :gate_kind, null: false     # e.g. "confirm_hero_shot", "cull_finalists"
      t.string     :status,    null: false, default: "open"   # open | approved | rejected | edited
      t.text       :agent_proposal              # what the step returned as its suggested answer
      t.text       :reviewer_decision           # what the reviewer chose (may equal proposal)
      t.jsonb      :context_snapshot, null: false, default: {}   # inputs the step was given
      t.jsonb      :reviewer_edits,   null: false, default: {}   # what the reviewer changed, if anything
      t.text       :notes                       # freeform reviewer notes for module 07
      t.datetime   :opened_at
      t.datetime   :closed_at
      t.timestamps
    end

    add_index :human_gates, [:piece_record_id, :status]
    add_index :human_gates, [:step_id, :status]
    add_index :human_gates, :opened_at
  end
end
```

```ruby
# app/models/human_gate.rb
class HumanGate < ApplicationRecord
  belongs_to :piece_record

  STATUSES = %w[open approved rejected edited].freeze
  validates :status, inclusion: { in: STATUSES }

  scope :open,    -> { where(status: "open") }
  scope :closed,  -> { where.not(status: "open") }

  def open? = status == "open"
  def duration_seconds = closed_at && opened_at ? (closed_at - opened_at).to_i : nil

  # Extract the reviewer's actual chosen values — module 07 reads this.
  def effective_output
    return JSON.parse(agent_proposal || "{}") if status == "approved"
    return JSON.parse(reviewer_decision || "{}") if reviewer_decision.present?
    {}
  end
end
```

### 2.1 `PieceRecord` gains a helper

```ruby
# app/models/piece_record.rb — additions
class PieceRecord < ApplicationRecord
  has_many :human_gates, dependent: :destroy

  def open_gate = human_gates.open.order(:opened_at).last

  def gate_history(step_id: nil)
    scope = human_gates.order(:opened_at)
    step_id ? scope.where(step_id: step_id) : scope
  end
end
```

---

## 3. `Workflow::StepDispatcher`

The single call site for every step class.

```ruby
# app/services/workflow/step_dispatcher.rb
module Workflow
  class StepDispatcher
    def self.call(step_id:, piece:, context: {})
      new(step_id: step_id, piece: piece, context: context).call
    end

    def initialize(step_id:, piece:, context:)
      @step_id = step_id
      @piece   = piece
      @context = context
      @registry_entry = registry_lookup!
    end

    def call
      klass = @registry_entry["klass"].constantize
      mark_running!

      result = klass.call(piece: @piece, context: @context)

      case result.status
      when :ok
        StatusMachine.transition!(@piece, to: next_status_after_ok, current_step: @step_id)
        result
      when :awaiting_human
        open_gate!(result)
        StatusMachine.transition!(@piece, to: "awaiting_human", current_step: @step_id)
        result
      when :failed
        StatusMachine.transition!(@piece, to: "failed", current_step: @step_id,
                                  last_error: result.message)
        result
      end
    rescue StandardError => e
      # Catches domain-specific exceptions from any module (search, etsy, compositor, KB loaders)
      # and turns them into a fail_step so the pipeline pauses rather than tearing down.
      StatusMachine.transition!(@piece, to: "failed", current_step: @step_id,
                                last_error: "#{e.class}: #{e.message}")
      raise
    end

    private

    def registry_lookup!
      entry = REGISTRY.find { |e| e["id"] == @step_id }
      raise ArgumentError, "Unknown step_id=#{@step_id.inspect}" unless entry
      entry
    end

    def mark_running!
      # If the piece was awaiting_human on this same step, closing that gate happens elsewhere
      # (the controller updates it before enqueuing the resume job). Here we only set status.
      return if @piece.nil?
      StatusMachine.transition!(@piece, to: "running", current_step: @step_id)
    end

    def open_gate!(result)
      return if @piece.nil?   # Track A/B run pre-piece; gates are recorded differently there
      HumanGate.create!(
        piece_record: @piece,
        step_id: @step_id,
        gate_kind: @registry_entry["title"].parameterize.underscore,
        status: "open",
        agent_proposal: result.data.to_json,
        context_snapshot: @context.deep_stringify_keys,
        opened_at: Time.current,
        notes: result.message
      )
    end

    def next_status_after_ok
      # An ok result at the end of the pipeline (P3_8 published_at) transitions to complete.
      # Otherwise: pending (waiting for the next step to be enqueued).
      last_step_of_pipeline?(@step_id) ? "complete" : "pending"
    end

    def last_step_of_pipeline?(step_id) = step_id == "P3_8"

    REGISTRY = begin
      raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
      # Flatten all phases into one lookup — track_a / track_b / track_c for phase_1,
      # steps for phase_2 and phase_3_module_1.
      [
        *(raw.dig("phase_1", "track_a", "steps") || []),
        *(raw.dig("phase_1", "track_b", "steps") || []),
        *(raw.dig("phase_1", "track_c", "steps") || []),
        *(raw.dig("phase_2", "steps") || []),
        *(raw.dig("phase_3_module_1", "steps") || [])
      ].freeze
    end
  end
end
```

---

## 4. `Workflow::StatusMachine`

The transitions are simple; keeping them in one class means they're auditable.

```ruby
# app/services/workflow/status_machine.rb
module Workflow
  class InvalidTransition < StandardError; end

  class StatusMachine
    # Legal transitions.
    # Any → failed is always allowed (any step can raise). failed → running requires an
    # explicit resume (see ResumePieceJob).
    TRANSITIONS = {
      "pending"        => %w[running failed],
      "running"        => %w[pending awaiting_human complete failed],
      "awaiting_human" => %w[running failed],
      "complete"       => %w[],                              # terminal
      "failed"         => %w[running pending]                # explicit resume only
    }.freeze

    def self.transition!(piece, to:, current_step: nil, last_error: nil)
      return if piece.nil?

      from = piece.status
      allowed = TRANSITIONS.fetch(from, [])
      unless allowed.include?(to)
        raise InvalidTransition, "PieceRecord ##{piece.id}: #{from} → #{to} not allowed. " \
                                 "Legal from #{from}: #{allowed.join(', ')}"
      end

      piece.update!(
        status: to,
        current_step: current_step || piece.current_step,
        last_error: to == "failed" ? last_error : nil
      )
    end
  end
end
```

---

## 5. Solid Queue jobs

### 5.1 `ProcessPieceJob` — advance a piece one step at a time

```ruby
# app/jobs/process_piece_job.rb
class ProcessPieceJob < ApplicationJob
  queue_as :default

  # step_id: the next step to run for this piece
  # context: whatever extra input that step needs (e.g. a human's approved override)
  def perform(piece_id:, step_id:, context: {})
    piece = PieceRecord.find(piece_id)

    # Refuse to run against uncommitted knowledge base — unless the piece already ran with dirty
    # (in which case it stays dirty; don't upgrade it silently).
    unless piece.dirty_run?
      begin
        Workflow::PreflightCheck.call!
      rescue Workflow::DirtyKnowledgeBaseError => e
        piece.update!(status: "failed", last_error: e.message)
        return
      end
    end

    result = Workflow::StepDispatcher.call(step_id: step_id, piece: piece,
                                           context: context.deep_symbolize_keys)

    return unless result.ok?

    # Advance to the next step if there is one.
    if (next_step = Workflow::PipelineRun.next_step_after(step_id, piece))
      ProcessPieceJob.perform_later(piece_id: piece.id, step_id: next_step)
    end
  end
end
```

### 5.2 `ResumePieceJob` — after a human gate is resolved

```ruby
# app/jobs/resume_piece_job.rb
class ResumePieceJob < ApplicationJob
  queue_as :default

  # gate_id: the HumanGate just closed by the reviewer
  def perform(gate_id:)
    gate  = HumanGate.find(gate_id)
    piece = gate.piece_record

    unless gate.status == "approved" || gate.status == "edited"
      # Rejected — piece stays failed/pending; the reviewer will initiate the next action.
      return
    end

    # Merge the reviewer's decision into the context for the resumed run.
    context = gate.context_snapshot.deep_symbolize_keys
                  .merge(confirmed: true)
                  .merge(gate.reviewer_edits.deep_symbolize_keys)

    # For steps whose completion IS the reviewer's confirmation (A5, B7, C2 chosen, P3_7),
    # re-invoke the same step_id — the step class checks `context[:confirmed]` and completes.
    # For steps that produced a proposal awaiting confirmation (B6 override, P3_2 hero,
    # P3_6 tone), same pattern: re-run with context populated.
    ProcessPieceJob.perform_later(piece_id: piece.id, step_id: gate.step_id, context: context)
  end
end
```

**Note on Track A/B jobs:** those tracks are `per_style` / `per_scene` and don't produce a
`PieceRecord`. They run through the same dispatcher but with `piece: nil` and context carrying the
style_slug / scene_template_id. See §7 for the rake tasks that drive them.

---

## 6. `Workflow::PipelineRun` — the daily entrypoint + next-step logic

```ruby
# app/services/workflow/pipeline_run.rb
module Workflow
  class PipelineRun
    DAILY_SEQUENCE = %w[C1 C2 P2_1 branch_2x P2_3 P2_4 P2_4b P2_5 P2_6 P3_1 P3_1b P3_2 P3_3 P3_4 P3_5 P3_6 P3_7 P3_8].freeze

    # Kick off a daily pipeline for one piece.
    # style_slug / scene_spec_id must be a locked spec.
    def self.start_daily(style_slug:, scene_spec_id:)
      spec = KnowledgeBase::StyleSpec.load(style_slug)
      scene = spec.scene(scene_spec_id)

      kb_version = PreflightCheck.call!.kb_version

      piece = PieceRecord.create!(
        style_spec_slug: style_slug,
        scene_spec_id: scene_spec_id,
        kb_version: kb_version,
        status: "pending"
      )
      piece.apply_spec!(spec, scene)
      piece.save!

      ProcessPieceJob.perform_later(piece_id: piece.id, step_id: "C1")
      piece
    end

    # After a step returns ok, figure out what to run next.
    def self.next_step_after(step_id, piece)
      # Step 1 → branch to one of 2a-2e
      return branch_2x_step(piece) if step_id == "P2_1"

      # 2a-2e → 3 (if a set) or 4 (if single)
      if %w[P2_2a P2_2b P2_2c P2_2d P2_2e].include?(step_id)
        return piece.piece_count.to_i > 1 ? "P2_3" : "P2_4"
      end

      # Terminal
      return nil if step_id == "P3_8"

      # Straight line for everything else
      idx = LINEAR.index(step_id)
      return nil if idx.nil?
      LINEAR[idx + 1]
    end

    LINEAR = %w[C1 C2 P2_0 P2_1 P2_3 P2_4 P2_4b P2_5 P2_6 P3_1 P3_1b P3_2 P3_3 P3_4 P3_5 P3_6 P3_7 P3_8].freeze

    def self.branch_2x_step(piece)
      Phase2::BranchRouter.klass_for(piece.placement_branch).step_id
    end
  end
end
```

---

## 7. Rake tasks

### 7.1 `lib/tasks/pipeline.rake`

```ruby
namespace :pipeline do
  desc "Run one piece through the daily pipeline. Usage: rake pipeline:daily style=japandi-v1 scene=behind_sofa_light_neutral"
  task daily: :environment do
    style = ENV.fetch("style")
    scene = ENV.fetch("scene")
    piece = Workflow::PipelineRun.start_daily(style_slug: style, scene_spec_id: scene)
    puts "Started daily pipeline. PieceRecord ##{piece.id}, kb_version=#{piece.kb_version}"
    puts "Run `bin/rails pipeline:status piece=#{piece.id}` to watch."
  end

  desc "Kick off Track A for a new style. Usage: rake pipeline:track_a style_slug=japandi-v1 style_name=Japandi"
  task track_a: :environment do
    slug = ENV.fetch("style_slug")
    name = ENV.fetch("style_name")
    context = { style_slug: slug, style_name: name }
    result = Workflow::StepDispatcher.call(step_id: "A0", piece: nil, context: context)
    puts "A0 -> #{result.status}. #{result.message}"
    puts "Findings JSON in the returned data; run subsequent A-steps via the console once A0 human-gate closes."
  end

  desc "Kick off Track B for a scene template. Usage: rake pipeline:track_b style_slug=japandi-v1 scene=behind_sofa_light_neutral"
  task track_b: :environment do
    slug  = ENV.fetch("style_slug")
    scene = ENV.fetch("scene")
    context = {
      style_slug: slug,
      scene_template_id: scene,
      scene_image: "scene_templates/assets/#{scene}.png"
    }
    result = Workflow::StepDispatcher.call(step_id: "B0", piece: nil, context: context)
    puts "B0 -> #{result.status}. #{result.message}"
  end

  desc "Resume a paused piece by closing its open gate. Usage: rake pipeline:resume gate=42 decision=approved"
  task resume: :environment do
    gate = HumanGate.find(ENV.fetch("gate"))
    gate.update!(status: ENV.fetch("decision", "approved"),
                 reviewer_decision: gate.agent_proposal,
                 closed_at: Time.current)
    ResumePieceJob.perform_later(gate_id: gate.id)
    puts "Gate ##{gate.id} → #{gate.status}. Resume job enqueued."
  end

  desc "Show status of a piece. Usage: rake pipeline:status piece=42"
  task status: :environment do
    piece = PieceRecord.find(ENV.fetch("piece"))
    puts "Piece ##{piece.id}"
    puts "  status:      #{piece.status}"
    puts "  current_step: #{piece.current_step}"
    puts "  kb_version:  #{piece.kb_version}#{' (DIRTY)' if piece.dirty_run?}"
    puts "  style/scene: #{piece.style_spec_slug}/#{piece.scene_spec_id}"
    puts "  last_error:  #{piece.last_error}" if piece.last_error.present?
    puts "  open gate:   ##{piece.open_gate&.id || '(none)'} (step=#{piece.open_gate&.step_id})"
    puts "  gates total: #{piece.human_gates.count} (#{piece.human_gates.closed.count} closed)"
  end
end
```

---

## 8. Review UI

Minimal — Rails scaffolds, no JavaScript framework.

### 8.1 Routes

```ruby
# config/routes.rb — additions
Rails.application.routes.draw do
  resources :reviews, only: [:index]
  resources :human_gates, only: [:show, :update]
  root "reviews#index"    # localhost:3000 opens the reviewer's task list
end
```

### 8.2 `ReviewsController` — the task list

```ruby
# app/controllers/reviews_controller.rb
class ReviewsController < ApplicationController
  def index
    @open_gates = HumanGate.open
                           .includes(:piece_record)
                           .order(opened_at: :desc)
                           .limit(50)
    @failed_pieces = PieceRecord.where(status: "failed")
                                .order(updated_at: :desc)
                                .limit(20)
  end
end
```

### 8.3 `HumanGatesController` — the per-gate review page

```ruby
# app/controllers/human_gates_controller.rb
class HumanGatesController < ApplicationController
  def show
    @gate = HumanGate.find(params[:id])
    @piece = @gate.piece_record
    @agent_proposal = JSON.parse(@gate.agent_proposal || "{}")
  end

  def update
    @gate = HumanGate.find(params[:id])
    decision = params[:decision]   # "approved" | "rejected" | "edited"

    edits = params[:reviewer_edits].to_unsafe_h rescue {}
    notes = params[:notes]

    @gate.update!(
      status: decision,
      reviewer_edits: edits,
      reviewer_decision: (decision == "edited" ? edits.to_json : @gate.agent_proposal),
      notes: notes,
      closed_at: Time.current
    )

    # Only resume the piece if the reviewer approved or edited. Rejections leave the piece for
    # the human to decide the next move (usually: rerun the previous step with different context,
    # or abandon).
    ResumePieceJob.perform_later(gate_id: @gate.id) if %w[approved edited].include?(decision)

    redirect_to reviews_path, notice: "Gate ##{@gate.id} → #{decision}."
  end
end
```

### 8.4 Views

```erb
<%# app/views/reviews/index.html.erb %>
<div class="max-w-4xl mx-auto p-6">
  <h1 class="text-2xl font-semibold mb-4">Awaiting review</h1>

  <% if @open_gates.empty? %>
    <p class="text-gray-500">No pieces awaiting review.</p>
  <% else %>
    <div class="space-y-3">
      <% @open_gates.each do |gate| %>
        <%= link_to human_gate_path(gate), class: "block border rounded-lg p-4 hover:bg-gray-50" do %>
          <div class="flex justify-between">
            <div>
              <div class="font-mono text-sm text-gray-600">Step <%= gate.step_id %></div>
              <div class="mt-1"><%= gate.notes.to_s.truncate(140) %></div>
            </div>
            <div class="text-right text-sm text-gray-500">
              Piece #<%= gate.piece_record_id %><br>
              <%= time_ago_in_words(gate.opened_at) %> ago
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
  <% end %>

  <% if @failed_pieces.any? %>
    <h2 class="text-xl font-semibold mt-8 mb-3">Failed pieces</h2>
    <div class="space-y-2">
      <% @failed_pieces.each do |p| %>
        <div class="border-l-4 border-red-500 pl-3 py-1">
          <span class="font-mono">Piece #<%= p.id %></span>
          at step <%= p.current_step %>: <span class="text-red-700"><%= p.last_error.to_s.truncate(180) %></span>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

```erb
<%# app/views/human_gates/show.html.erb %>
<div class="max-w-3xl mx-auto p-6">
  <div class="mb-4">
    <%= link_to "← Back", reviews_path, class: "text-blue-600 hover:underline" %>
  </div>

  <h1 class="text-2xl font-semibold">Piece #<%= @piece.id %> — Step <%= @gate.step_id %></h1>
  <p class="text-gray-600 mt-1"><%= @gate.notes %></p>

  <h2 class="text-lg font-semibold mt-6">Agent proposal</h2>
  <pre class="bg-gray-50 border rounded p-3 text-sm overflow-auto"><%= JSON.pretty_generate(@agent_proposal) %></pre>

  <h2 class="text-lg font-semibold mt-6">Piece context</h2>
  <dl class="mt-2 text-sm grid grid-cols-2 gap-2">
    <dt class="text-gray-500">style/scene</dt>
    <dd><%= @piece.style_spec_slug %> / <%= @piece.scene_spec_id %></dd>
    <dt class="text-gray-500">mood / content / role</dt>
    <dd><%= @piece.mood %> / <%= @piece.content_type %> / <%= @piece.color_role %></dd>
    <dt class="text-gray-500">kb_version</dt>
    <dd class="font-mono text-xs"><%= @piece.kb_version %></dd>
  </dl>

  <%= form_with url: human_gate_path(@gate), method: :patch, local: true, class: "mt-6 space-y-4" do |f| %>
    <div>
      <%= f.label :notes, "Reviewer notes (optional — module 07 reads these)", class: "block text-sm font-medium" %>
      <%= f.text_area :notes, rows: 3, class: "mt-1 w-full border rounded p-2" %>
    </div>

    <div>
      <%= f.label :reviewer_edits, "Edits (JSON) — leave blank to approve as-is", class: "block text-sm font-medium" %>
      <%= f.text_area :reviewer_edits, rows: 4, class: "mt-1 w-full font-mono text-sm border rounded p-2" %>
      <p class="text-xs text-gray-500 mt-1">If you edit the proposal, paste replacement JSON here. Keys will be merged into context on resume.</p>
    </div>

    <div class="flex gap-2">
      <%= f.submit "Approve", name: "decision", value: "approved",
                    class: "bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700" %>
      <%= f.submit "Approve with edits", name: "decision", value: "edited",
                    class: "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" %>
      <%= f.submit "Reject", name: "decision", value: "rejected",
                    class: "bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700" %>
    </div>
  <% end %>
</div>
```

---

## 9. The 17 human gates — how each one is realised

Every gate from module 04 §7's cross-pipeline rollup maps to a step class returning `needs_human`,
which the dispatcher turns into a `HumanGate` row and a `status: awaiting_human` transition. This
section is the mapping — for auditability, so a reader can verify "every documented gate is
implemented" against `step_registry.yml`.

| # | Step | Gate kind | Where the pause happens | Where the approve resumes |
|---|---|---|---|---|
| 1  | A0 | style go/no-go   | `ValidateStyle#perform` returns needs_human | rake `pipeline:resume` closes gate; human curates next |
| 2  | A1 | curate references | `BuildReferenceSet#perform` needs_human | same |
| 3  | A2 | mood confirm      | `SortMood#perform` needs_human | same |
| 4  | A3 | content type      | `SortContentType#perform` needs_human | same |
| 5  | A4 | frame form        | `SortFrameForm#perform` needs_human | same |
| 6  | A5 | lock style entry  | `LockStyleEntry#perform` needs_human unless `confirmed:` | on approve, spec file is written |
| 7  | B0 | template fixed?   | `ConfirmSceneTemplate#perform` needs_human | same |
| 8  | B6 | override call     | `ColorRole#perform` needs_human when minimalist_modern default fires | context[:catalog_strategy_override] carried forward |
| 9  | B7 | lock scene entry  | `LockSceneEntry#perform` needs_human unless `confirmed:` | on approve, scene axes written |
| 10 | C2 | cull to finalists | `CullToFinalists#perform` needs_human twice (finalists, then chosen) | two separate gates, two resumes |
| 11 | P2_0 | load style spec | `LoadStyleSpec#perform` — validates + reports; human-tagged as checkpoint |
| 12 | P2_3 | theme confirm   | `UnifyByTheme#perform` needs_human on any failed check | on approve, next daily step |
| 13 | P2_7 | weekly review   | `WeeklyReview#perform` — human decides repeat/extend/rotate |
| 14 | P3_1b | photo confirm  | `GeneratePhotoTypes#perform` needs_human after generation | on approve, P3_2 |
| 15 | P3_2 | hero shot       | `SelectAndOrderPhotos#perform` needs_human | on approve, P3_3 |
| 16 | P3_6 | tone confirm    | `WriteDescription#perform` needs_human always (per ownership tag) | on approve, P3_7 |
| 17 | P3_7 | shipping/policy | `ShippingAndReturns#perform` needs_human unless `confirmed:` | on approve, P3_8 |

Note that P3_2 (hero shot) also implicitly gates the technical checks — if the hero image fails
the 635px floor, the same `needs_human` surface tells the reviewer.

---

## 10. Verification for this module

```bash
# 1. Migration for human_gates ran and the model loads
bin/rails runner 'puts HumanGate.column_names.size'    # expect 11+

# 2. All 17 gates from module 04 §7 rollup are implementable — count needs_human calls
bin/rails runner '
  step_classes = Dir[Rails.root.join("app/steps/**/*.rb")]
  needs_human_hits = step_classes.sum { |f| File.read(f).scan(/needs_human/).size }
  puts "needs_human call sites: #{needs_human_hits}"
  puts "at least 17: #{needs_human_hits >= 17}"
'

# 3. The step registry loads via the dispatcher (no MISSING klass)
bin/rails runner '
  raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
  all = [
    *(raw.dig("phase_1", "track_a", "steps") || []),
    *(raw.dig("phase_1", "track_b", "steps") || []),
    *(raw.dig("phase_1", "track_c", "steps") || []),
    *(raw.dig("phase_2", "steps") || []),
    *(raw.dig("phase_3_module_1", "steps") || [])
  ]
  puts "total steps: #{all.size}"    # expect 38
  missing = all.reject { |s| s["klass"].safe_constantize }
  if missing.any?
    puts "MISSING classes: #{missing.map { |s| s['klass'] }.inspect}"
  else
    puts "all step classes resolve: ok"
  end
'

# 4. State machine rejects illegal transitions
bin/rails runner '
  piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s",
                              kb_version: "dirty:test", status: "complete")
  begin
    Workflow::StatusMachine.transition!(piece, to: "running")
    puts "FAIL: allowed complete→running"
  rescue Workflow::InvalidTransition
    puts "correctly rejects complete→running: ok"
  end
  piece.destroy!
'

# 5. Legal transitions succeed
bin/rails runner '
  piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s",
                              kb_version: "dirty:test", status: "pending")
  Workflow::StatusMachine.transition!(piece, to: "running", current_step: "P3_1")
  raise "wrong" unless piece.reload.status == "running"
  Workflow::StatusMachine.transition!(piece, to: "awaiting_human")
  raise "wrong" unless piece.reload.status == "awaiting_human"
  Workflow::StatusMachine.transition!(piece, to: "running")
  raise "wrong" unless piece.reload.status == "running"
  puts "pending→running→awaiting_human→running: ok"
  piece.destroy!
'

# 6. Dispatcher opens a HumanGate on awaiting_human and transitions correctly
bin/rails runner '
  # Build a fake step that returns needs_human, register temporarily via a stub
  module Steps::Stub
    class NeedsHumanTest < Steps::Base
      step id: "TEST_NH", mechanism: :human, ownership: "[HUMAN ONLY]"
      def perform = needs_human("test message", { proposed: "x" })
    end
  end
  Workflow::StepDispatcher.const_get(:REGISTRY) << { "id" => "TEST_NH", "klass" => "Steps::Stub::NeedsHumanTest", "title" => "test" }

  piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s",
                              kb_version: "dirty:test", status: "pending")
  Workflow::StepDispatcher.call(step_id: "TEST_NH", piece: piece)
  gate = piece.reload.open_gate
  puts "gate opened: #{gate.present?}"
  puts "piece status: #{piece.status}"    # expect awaiting_human
  puts "gate step_id: #{gate.step_id}"    # expect TEST_NH
  gate.destroy!
  piece.destroy!
'

# 7. ResumePieceJob no-ops on rejected gates
bin/rails runner '
  piece = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s",
                              kb_version: "dirty:test", status: "awaiting_human")
  gate = HumanGate.create!(piece_record: piece, step_id: "TEST_NH",
                            gate_kind: "test", status: "rejected",
                            agent_proposal: "{}", context_snapshot: {},
                            opened_at: 1.minute.ago, closed_at: Time.current)
  before = piece.status
  # This must NOT enqueue a job or transition
  ResumePieceJob.new.perform(gate_id: gate.id)
  puts "status unchanged: #{piece.reload.status == before}"    # expect true
  gate.destroy!
  piece.destroy!
'

# 8. PipelineRun#next_step_after branches correctly on P2_1
bin/rails runner '
  # single piece
  piece = PieceRecord.new(space_math: "single", piece_count: 1, placement_branch: "single")
  # In practice next_step_after("P2_1") returns branch_2x_step (P2_2a for single)
  puts Workflow::PipelineRun.next_step_after("P2_1", piece)   # expect P2_2a
  # after P2_2a with piece_count 1 → P2_4 (skips P2_3)
  puts Workflow::PipelineRun.next_step_after("P2_2a", piece)  # expect P2_4
  # after P2_2b with piece_count 3 → P2_3
  piece.piece_count = 3
  puts Workflow::PipelineRun.next_step_after("P2_2b", piece)  # expect P2_3
'

# 9. Rake tasks are registered
bin/rails -T pipeline 2>/dev/null | grep -c "pipeline:"   # expect 5

# 10. Routes render
bin/rails routes | grep -E "reviews|human_gates" | head -5
```

**Also verify by hand:**
- `HumanGate.effective_output` returns the reviewer's edited JSON when status is `"edited"`, and
  the agent's proposal when status is `"approved"` — module 07 reads this to trace what
  actually got applied vs. what was proposed.
- `ProcessPieceJob` refuses to run on a dirty knowledge base except when the piece itself was
  already recorded with a `dirty:` prefix — a dirty piece stays dirty; a clean piece never
  silently becomes dirty mid-run.
- The review UI at `localhost:3000` renders the open-gate list and lets you approve/reject one
  gate end-to-end without needing to touch the console.

---

## 11. Manifest coverage

| Manifest ID | Item | Where |
|---|---|---|
| — | State machine on `PieceRecord.status` (5 states, legal transitions) | §4 |
| — | Solid Queue jobs advance the pipeline through the dispatcher | §5 |
| — | `HumanGate` audit table (module 07 reads these) | §2 |
| — | Rake task entrypoints for daily / track_a / track_b / resume / status | §7 |
| — | Minimal review UI at `/` (task list + per-gate approve/reject/edit) | §8 |
| — | The 17 human gates all wired to `needs_human` in their step classes | §9 |
| — | Preflight `git`-clean guard is honoured at job start (module 00 §5) | §5.1 |
| — | Track A/B run pre-piece; dispatcher tolerates `piece: nil` | §3 `open_gate!` early return |

**Deferred to module 07:** the performance-summary export that populates `P2_7`'s context, the
weekly-review job that reads `HumanGate` notes to feed Claude, and the git-diff proposal flow.
