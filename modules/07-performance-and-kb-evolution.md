# Module 07 — Performance Feedback & Knowledge-Base Evolution

> **Self-contained.** This module has no new domain rules — it's the closed-loop machinery that
> reads what modules 03–05 produced, hands it to Claude for analysis, captures Claude's proposed
> edits to `knowledge_base/` as git-diffs, and gives you the reviewer surface to accept or reject
> each one. The loop the user asked for: run → measure → analyse → propose → apply → run.

---

## Contract

**Depends on:** module 00 (`PieceRecord`, `PerformanceSnapshot`, `Pipeline::KB_ROOT`), module 05
(published listings with `etsy_listing_id`), module 06 (`HumanGate` audit trail).

**Provides:**
- `app/services/performance/etsy_stats_fetcher.rb` — pulls Etsy Shop Stats + listing metrics into
  `PerformanceSnapshot` rows
- `app/services/performance/weekly_export.rb` — builds the structured performance summary handed
  to Claude
- `app/services/kb_evolution/proposer.rb` — calls Claude with the export + the current KB files
  and captures Claude's proposed file diffs
- `app/services/kb_evolution/proposal.rb` + `KbProposal` model — one proposal per file-change
  suggestion, with a status field for reviewer decision
- `KbProposalsController` + review UI — approve/reject/edit each proposal; approved ones apply as
  file writes ready for `git add`
- `lib/tasks/evolution.rake` — CLI: `evolution:refresh_stats`, `evolution:export`,
  `evolution:propose`, `evolution:apply`
- Solid Queue jobs for the weekly refresh + export + proposal cycle
- `knowledge_base/rules/anti_regressions.yml` — the safeguard rules that block proposals from
  suggesting Etsy's documented anti-patterns

**Consumed by:** the human running the loop each week, and (indirectly) every future pipeline run
after a proposal is applied.

**Must not:** apply any KB file change without an explicit reviewer approval action — the whole
point is that git-diff review IS the validation step. Auto-applied changes defeat that.

---

## 1. The loop, explicitly

```
[Week N]
   Pipeline runs (modules 03–05) — publishes listings, records PieceRecords with kb_version
      ↓
[Every day, daily]
   Performance::EtsyStatsFetcher — pulls views/favorites/orders per published listing
   Writes PerformanceSnapshot rows keyed by (piece_record_id, captured_on)
      ↓
[End of week N]
   Performance::WeeklyExport — joins PieceRecord + PerformanceSnapshot + HumanGate + kb_version
   into a structured markdown+JSON report
      ↓
   KbEvolution::Proposer — sends the report + current KB files to Claude via reasoned prompt
   Claude returns 0-N ProposalSuggestion objects (each = target file, old snippet, new snippet, why)
      ↓
[Reviewer sits down for weekly review]
   /kb_proposals UI shows each proposal as a rendered diff
   Reviewer approves / rejects / edits each one
   Approved proposals are written to disk in knowledge_base/ (still uncommitted)
      ↓
   Reviewer runs `git diff knowledge_base/` and commits — the git commit IS the validation
      ↓
[Week N+1]
   Preflight check sees clean KB, next daily run stamps its PieceRecords with the new SHA
   Loop repeats
```

Every arrow is either a job, a rake task, or a reviewer action. Nothing implicit, nothing running
under the assumption that "obviously the next thing will happen."

---

## 2. Two schema additions

### 2.1 `PerformanceSnapshot` is already defined (module 00 §9.2)

Module 00 created the table. This module *populates* it via `Etsy::ApiClient` calls. No schema
change needed here.

### 2.2 `KbProposal` — one row per suggested file change

```ruby
# db/migrate/XXXXXX_create_kb_proposals.rb
class CreateKbProposals < ActiveRecord::Migration[8.0]
  def change
    create_table :kb_proposals do |t|
      t.string  :cycle_id,   null: false                   # groups proposals from one Claude call
      t.string  :target_path, null: false                   # e.g. "knowledge_base/rules/etsy_tags.yml"
      t.string  :change_type, null: false                   # edit_snippet | append | replace_file
      t.text    :old_snippet                                # what was there (empty for append)
      t.text    :new_snippet, null: false                   # what Claude proposes
      t.text    :rationale,   null: false                   # Claude's grounding — must cite performance data
      t.jsonb   :evidence, null: false, default: {}         # {piece_ids: [], listing_ids: [], metrics: {}}
      t.string  :status,      null: false, default: "open"  # open | approved | rejected | edited | applied
      t.text    :reviewer_edits                             # the reviewer's counter-proposed new_snippet
      t.text    :reviewer_notes                             # freeform reasoning for module 07's own audit
      t.datetime :opened_at
      t.datetime :closed_at
      t.datetime :applied_at
      t.timestamps
    end

    add_index :kb_proposals, [:cycle_id, :status]
    add_index :kb_proposals, :target_path
    add_index :kb_proposals, :status
  end
end
```

```ruby
# app/models/kb_proposal.rb
class KbProposal < ApplicationRecord
  STATUSES = %w[open approved rejected edited applied].freeze
  CHANGE_TYPES = %w[edit_snippet append replace_file].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :change_type, inclusion: { in: CHANGE_TYPES }
  validates :target_path, format: { with: %r{\Aknowledge_base/} }   # locked to KB directory

  scope :open,      -> { where(status: "open") }
  scope :for_cycle, ->(id) { where(cycle_id: id) }

  # Effective content to write when applying — reviewer edit wins over Claude's proposal.
  def effective_new_snippet
    return reviewer_edits if status == "edited" && reviewer_edits.present?
    new_snippet
  end

  # Guardrail: the target file must exist for edit_snippet / must be inside knowledge_base/.
  # This is enforced again in KbEvolution::Applier before the write happens.
  def target_pathname
    Rails.root.join(target_path)
  end
end
```

**Design note on `target_path` validation:** the `format: { with: %r{\Aknowledge_base/} }` regex is
one of the two guardrails preventing a bad Claude proposal from touching anything outside the
knowledge base. The other is a runtime check in `KbEvolution::Applier` (§6.3). Two layers because
this one fails at proposal-creation time (surfaces the error immediately) and the runtime check
catches anything that somehow bypassed it.

---

## 3. Performance data collection

### 3.1 `Performance::EtsyStatsFetcher`

Pulls per-listing views/favorites/orders and shop-level search terms from Etsy's Open API. Called
daily, populates `PerformanceSnapshot`.

```ruby
# app/services/performance/etsy_stats_fetcher.rb
module Performance
  class EtsyStatsFetcher
    # For each published PieceRecord, fetch current-day metrics and upsert a snapshot for today.
    # Idempotent per (piece_record_id, captured_on) — safe to re-run the same day.
    def self.call(date: Date.current)
      PieceRecord.published.trustworthy.find_each do |piece|
        fetch_and_upsert(piece, date)
      end
    end

    def self.fetch_and_upsert(piece, date)
      client = Etsy::Adapter.build
      return if client.name == "manual"    # manual adapter has no fetch; skip silently

      metrics = client.fetch_listing_stats(listing_id: piece.etsy_listing_id, date: date)

      PerformanceSnapshot.find_or_initialize_by(
        piece_record_id: piece.id, captured_on: date
      ).tap do |s|
        s.views       = metrics.fetch(:views, 0)
        s.favorites   = metrics.fetch(:favorites, 0)
        s.orders      = metrics.fetch(:orders, 0)
        s.revenue     = metrics.fetch(:revenue, 0)
        s.search_terms = metrics.fetch(:search_terms, [])
        s.raw         = metrics
        s.save!
      end
    rescue Etsy::ApiError => e
      Rails.logger.warn "EtsyStatsFetcher: piece #{piece.id} failed — #{e.message}"
    end
  end
end
```

**Note on `fetch_listing_stats`:** this is a new method on `Etsy::ApiClient` not covered in module
05 (05's adapter only creates listings and fetches the category tree). Add it now — hitting the
`/application/shops/{shop_id}/listings/{listing_id}/stats` endpoint plus the Shop Stats endpoint
for search terms. **Verify endpoints against `developers.etsy.com` before running** — same caveat
as module 05.

### 3.2 Daily refresh job

```ruby
# app/jobs/refresh_performance_snapshots_job.rb
class RefreshPerformanceSnapshotsJob < ApplicationJob
  queue_as :default

  def perform
    Performance::EtsyStatsFetcher.call(date: Date.current)
  end
end
```

Schedule via a rake task or Solid Queue's recurring job feature — Rails 8 supports scheduled jobs
natively.

---

## 4. Weekly export

The structured report handed to Claude. Two files: a human-readable markdown summary (for you to
read alongside), and a machine-readable JSON block (what Claude actually reasons over).

### 4.1 `Performance::WeeklyExport`

```ruby
# app/services/performance/weekly_export.rb
module Performance
  class WeeklyExport
    def self.call(week_ending: Date.current)
      new(week_ending: week_ending).call
    end

    def initialize(week_ending:)
      @week_ending = week_ending
      @week_start  = week_ending - 6.days
    end

    def call
      pieces = pieces_in_window
      summary = build_summary(pieces)

      md_path   = write_markdown(summary)
      json_path = write_json(summary)

      { markdown_path: md_path, json_path: json_path,
        piece_count: pieces.size, cycle_id: cycle_id }
    end

    private

    def cycle_id
      @cycle_id ||= "cycle_#{@week_ending.strftime('%Y%m%d')}_#{SecureRandom.hex(3)}"
    end

    def pieces_in_window
      PieceRecord.published
                 .trustworthy      # excludes dirty:* runs — analysis has to be reproducible
                 .where(published_at: @week_start.beginning_of_day..@week_ending.end_of_day)
                 .includes(:performance_snapshots, :human_gates)
    end

    def build_summary(pieces)
      {
        window: { start: @week_start.iso8601, end: @week_ending.iso8601 },
        cycle_id: cycle_id,
        piece_count: pieces.size,
        kb_versions_in_play: pieces.map(&:kb_version).uniq,
        pieces: pieces.map { |p| piece_summary(p) },
        aggregates: aggregate_by_axis(pieces),
        gate_patterns: gate_pattern_summary(pieces),
        anti_pattern_watch: anti_pattern_flags(pieces)
      }
    end

    def piece_summary(p)
      last = p.performance_snapshots.order(:captured_on).last
      first = p.performance_snapshots.order(:captured_on).first
      {
        piece_id: p.id,
        etsy_listing_id: p.etsy_listing_id,
        kb_version: p.kb_version,
        style_slug: p.style_spec_slug,
        scene_spec_id: p.scene_spec_id,
        axes: {
          mood: p.mood, content_type: p.content_type, color_role: p.color_role_confirmed,
          frame_material: p.frame_material_category, matting: p.matting_technique
        },
        listing: {
          title: p.listing_title, tags: p.listing_tags, category: p.listing_category
        },
        metrics: {
          views: last&.views.to_i,
          favorites: last&.favorites.to_i,
          orders: last&.orders.to_i,
          revenue: last&.revenue.to_f,
          conversion_rate: last&.conversion_rate&.round(4),
          days_live: (last&.captured_on && first&.captured_on) ?
                       (last.captured_on - first.captured_on).to_i + 1 : 0,
          top_search_terms: last&.search_terms.to_a.first(5)
        },
        gate_decisions: p.human_gates.closed.map { |g|
          { step_id: g.step_id, status: g.status, notes: g.notes.to_s[0, 200] }
        }
      }
    end

    # Aggregate metrics by each axis value. This is what lets Claude say
    # "pieces with color_role=color_burst got 2.3x more views than line_only in this window"
    # without having to reconstruct the join itself.
    def aggregate_by_axis(pieces)
      %i[mood content_type color_role frame_material].each_with_object({}) do |axis, agg|
        agg[axis] = pieces.group_by { |p| p.send(axis == :frame_material ? :frame_material_category : axis) }
                          .transform_values { |grp|
                            {
                              piece_count: grp.size,
                              avg_views: avg(grp, :views),
                              avg_favorites: avg(grp, :favorites),
                              avg_orders: avg(grp, :orders),
                              total_revenue: grp.sum { |p| p.performance_snapshots.order(:captured_on).last&.revenue.to_f }.round(2)
                            }
                          }
      end
    end

    def avg(pieces, metric_key)
      values = pieces.map { |p| p.performance_snapshots.order(:captured_on).last&.send(metric_key).to_i }
      return 0 if values.empty?
      (values.sum.to_f / values.size).round(2)
    end

    def gate_pattern_summary(pieces)
      pieces.flat_map(&:human_gates).flat_map { |g| g }.group_by(&:step_id)
            .transform_values { |gates|
              {
                total: gates.size,
                rejected: gates.count { |g| g.status == "rejected" },
                edited: gates.count { |g| g.status == "edited" },
                approved: gates.count { |g| g.status == "approved" }
              }
            }
    end

    def anti_pattern_flags(pieces)
      # Read the Etsy anti-patterns rule file and check whether any observed pattern in this
      # window looks like one Claude might otherwise "discover" and try to propose.
      anti = KnowledgeBase::RuleSet.load("etsy_antipatterns").rules
      flags = []
      # Example: renewal-chasing — check for pieces republished mid-window.
      # (Placeholder pattern; the actual detection depends on Etsy stats richness. Kept as an
      # explicit hook so the anti-pattern watch is visible in the export even if empty.)
      flags
    end

    def write_markdown(summary)
      path = Rails.root.join("tmp", "evolution", "#{cycle_id}_summary.md")
      path.dirname.mkpath
      path.write(markdown_render(summary))
      path.to_s
    end

    def write_json(summary)
      path = Rails.root.join("tmp", "evolution", "#{cycle_id}_data.json")
      path.dirname.mkpath
      path.write(JSON.pretty_generate(summary))
      path.to_s
    end

    def markdown_render(s)
      <<~MD
        # Weekly Performance Export — #{s[:window][:start]} to #{s[:window][:end]}

        Cycle ID: `#{s[:cycle_id]}`
        Pieces published this window: #{s[:piece_count]}
        Knowledge-base versions in play: #{s[:kb_versions_in_play].join(', ')}

        ## Per-piece summary

        #{s[:pieces].map { |p| piece_md(p) }.join("\n\n")}

        ## Aggregates by axis

        #{aggregates_md(s[:aggregates])}

        ## Gate patterns

        #{gate_patterns_md(s[:gate_patterns])}

        ## Anti-pattern watch

        #{s[:anti_pattern_watch].any? ? s[:anti_pattern_watch].to_yaml : '(no flags this window)'}
      MD
    end

    def piece_md(p)
      m = p[:metrics]
      <<~M
        ### Piece ##{p[:piece_id]} — `#{p[:etsy_listing_id]}`
        - Axes: #{p[:axes].to_json}
        - KB version: `#{p[:kb_version]}`
        - Views: #{m[:views]} / Favorites: #{m[:favorites]} / Orders: #{m[:orders]} / Conversion: #{m[:conversion_rate]}
        - Days live: #{m[:days_live]}
        - Top search terms: #{m[:top_search_terms].join(', ')}
      M
    end

    def aggregates_md(agg)
      agg.map { |axis, groups|
        rows = groups.map { |val, m|
          "  - `#{val}`: #{m[:piece_count]} pieces, avg views #{m[:avg_views]}, avg orders #{m[:avg_orders]}, total revenue $#{m[:total_revenue]}"
        }.join("\n")
        "**By #{axis}**\n#{rows}"
      }.join("\n\n")
    end

    def gate_patterns_md(patterns)
      patterns.map { |step, counts|
        "- **#{step}**: #{counts[:total]} total → approved #{counts[:approved]}, edited #{counts[:edited]}, rejected #{counts[:rejected]}"
      }.join("\n")
    end
  end
end
```

---

## 5. The KB evolution proposal cycle

### 5.1 `KbEvolution::Proposer` — hand it to Claude

```ruby
# app/services/kb_evolution/proposer.rb
module KbEvolution
  class ProposalGenerationError < StandardError; end

  class Proposer
    def self.call(cycle_id:)
      new(cycle_id: cycle_id).call
    end

    def initialize(cycle_id:)
      @cycle_id = cycle_id
      @export_json_path = Rails.root.join("tmp", "evolution", "#{cycle_id}_data.json")
      raise ProposalGenerationError, "Export not found for cycle #{cycle_id}" unless @export_json_path.exist?
    end

    def call
      report = JSON.parse(@export_json_path.read)
      kb_snapshot = build_kb_snapshot

      result = RubyLLM.chat(model: Pipeline::TEXT_MODEL)
                      .with_schema(KbEvolution::ProposalListSchema)
                      .ask(build_prompt(report, kb_snapshot))
                      .content

      persist_proposals(result["proposals"])
    end

    private

    # Snapshot every KB file the reviewer might want to change: rules/*, prompts/*, style_specs/*.
    # Claude sees the full text of each; it needs the current content to propose edits.
    def build_kb_snapshot
      snapshot = {}
      Dir[Pipeline::KB_ROOT.join("**/*.{yml,md}")].each do |path|
        rel = Pathname.new(path).relative_path_from(Rails.root).to_s
        snapshot[rel] = File.read(path)
      end
      snapshot
    end

    def build_prompt(report, kb_snapshot)
      <<~PROMPT
        You are analysing one week of Etsy listing performance and proposing specific,
        evidence-grounded edits to the knowledge base that produced those listings.

        # Ground rules

        1. **Every proposal must cite specific pieces or metrics from the report.** No proposal
           that reads "we should make listings more engaging" — it must be "pieces with
           color_role=color_burst averaged 2.3x more views (N=4) than line_only (N=7), so
           color_role.yml's per-role default for color_burst should shift to X."
        2. **Only edit files inside `knowledge_base/`.** Never propose changes to `app/`,
           `config/`, or anywhere else.
        3. **Do not propose Etsy anti-patterns.** The rules in
           `knowledge_base/rules/etsy_antipatterns.yml` list things Etsy explicitly says do not
           work (renewal-chasing, self-search verification, assuming Etsy Plus / Star Seller
           / Etsy Ads move ranking). Proposals matching those patterns will be auto-rejected —
           don't waste a slot on them.
        4. **Small, testable changes beat sweeping ones.** Change one rule value, one prompt
           line, one axis default at a time. Sweeping rewrites can't be attributed to a
           specific effect next week.
        5. **N=1 is not evidence.** A single piece performing well doesn't justify changing a
           rule. Wait for a pattern across at least 3 pieces before proposing an edit driven
           by outcomes.
        6. **If the data is too sparse or the week too quiet, say so and propose zero edits.**
           Proposing weak changes to look useful is worse than proposing nothing.

        # The performance report

        ```json
        #{JSON.pretty_generate(report)}
        ```

        # Current knowledge base

        ```yaml
        #{kb_snapshot.map { |path, content| "# --- #{path} ---\n#{content}" }.join("\n\n")}
        ```

        Return JSON matching the required schema. Each proposal names a specific file, the exact
        snippet to replace (or "append"), the new snippet, and a rationale that cites the
        specific pieces/metrics from the report that justify it.
      PROMPT
    end

    def persist_proposals(proposals)
      Array(proposals).map do |raw|
        KbProposal.create!(
          cycle_id: @cycle_id,
          target_path: raw["target_path"],
          change_type: raw["change_type"],
          old_snippet: raw["old_snippet"],
          new_snippet: raw["new_snippet"],
          rationale: raw["rationale"],
          evidence: raw["evidence"] || {},
          status: "open",
          opened_at: Time.current
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "Skipped invalid proposal: #{e.message} — raw=#{raw.inspect}"
        nil
      end.compact
    end
  end
end
```

### 5.2 Schema

```ruby
# app/llm/schemas/kb_evolution/proposal_list_schema.rb
module KbEvolution
  class ProposalListSchema < RubyLLM::Schema
    integer :proposal_count,
            description: "How many proposals below. Zero is a legitimate answer if the data doesn't justify any."
    array :proposals do
      object do
        string :target_path,
               description: "Path relative to Rails root — must start with 'knowledge_base/'"
        string :change_type,
               enum: %w[edit_snippet append replace_file],
               description: "'edit_snippet' replaces exact old_snippet with new_snippet. 'append' adds new_snippet to end of file. 'replace_file' overwrites the whole file (use sparingly)."
        string :old_snippet,
               description: "Exact text to be replaced. Required for edit_snippet; empty for append; full current file for replace_file."
        string :new_snippet,
               description: "The replacement text. Required."
        string :rationale,
               description: "Must cite specific pieces or aggregate metrics from the report. No hand-waving."
        object :evidence do
          array :piece_ids, of: :integer, description: "Piece IDs supporting the change"
          array :listing_ids, of: :string, description: "Etsy listing IDs supporting the change"
          object :metrics, description: "Specific numbers cited"
        end
      end
    end
    string :summary_notes,
           description: "Overall reading of the week — the data-was-sparse case goes here."
  end
end
```

### 5.3 Anti-regression safeguard file

```yaml
# knowledge_base/rules/anti_regressions.yml
meta:
  source: "Module 07 §5 — proposal safeguards"
  citation: "Cross-cutting; sources the anti-pattern content from Phase 3 §2.6 (etsy_antipatterns.yml)"
  volatility: static
  note: >
    This file exists to prevent Claude's evolution loop from "discovering" a false pattern in
    a short data window and proposing an edit that walks the pipeline into an Etsy-documented
    anti-pattern. Read by Proposer at proposal-generation time (via the prompt) and by the
    reviewer UI (via the auto-flag on incoming proposals).

rules:
  hard_blocks:
    - name: renewal_chasing
      description: "Proposals suggesting renewing listings to chase the Etsy 'new listing' boost"
      pattern_indicators:
        - "renew"
        - "relist"
        - "refresh listing"
      source_rule: "etsy_antipatterns.yml → renewal_chasing"

    - name: self_search_verification
      description: "Proposals suggesting judging ranking by searching own shop"
      pattern_indicators:
        - "search my own"
        - "verify by searching"
      source_rule: "etsy_antipatterns.yml → self_search_verification"

    - name: plus_starseller_ads_assumed_ranking
      description: "Proposals assuming Etsy Plus, Star Seller, or Etsy Ads affect organic ranking"
      pattern_indicators:
        - "etsy plus"
        - "star seller"
        - "etsy ads for ranking"
      source_rule: "etsy_antipatterns.yml → plus_starseller_ads_assumed_ranking"

  soft_flags:
    - name: single_piece_generalisation
      description: "Proposal cites only one piece as evidence"
      trigger: "evidence.piece_ids.size < 3"
      surface_as: warning
      reasoning: >
        Per proposer prompt rule 5, N=1 isn't a pattern. Flag but don't hard-block — the
        reviewer might still see something worth acting on.

    - name: sweeping_replace_file
      description: "change_type=replace_file, rewriting an entire rule file"
      surface_as: warning
      reasoning: >
        Per proposer prompt rule 4, small changes beat sweeping ones. Not blocked — sometimes
        a rewrite is warranted — but every one gets a second look.
```

---

## 6. Reviewer surface: `/kb_proposals`

### 6.1 Routes

```ruby
# config/routes.rb — additions
resources :kb_proposals, only: [:index, :show, :update] do
  member { post :apply }
end
```

### 6.2 Controller

```ruby
# app/controllers/kb_proposals_controller.rb
class KbProposalsController < ApplicationController
  def index
    @open_proposals = KbProposal.open.order(:target_path, :created_at)
    @cycles = KbProposal.distinct.pluck(:cycle_id).sort.reverse
  end

  def show
    @proposal = KbProposal.find(params[:id])
    @current_content = File.read(@proposal.target_pathname) rescue nil
    @anti_regression_flags = KbEvolution::AntiRegressionScanner.call(@proposal)
  end

  def update
    @proposal = KbProposal.find(params[:id])
    decision = params[:decision]   # approved | rejected | edited

    @proposal.update!(
      status: decision,
      reviewer_edits: (decision == "edited" ? params[:reviewer_edits] : nil),
      reviewer_notes: params[:reviewer_notes],
      closed_at: Time.current
    )

    redirect_to kb_proposals_path,
                notice: "Proposal ##{@proposal.id} → #{decision}. #{'Run apply to write to disk.' if %w[approved edited].include?(decision)}"
  end

  def apply
    @proposal = KbProposal.find(params[:id])
    unless %w[approved edited].include?(@proposal.status)
      return redirect_to kb_proposals_path, alert: "Cannot apply a proposal that isn't approved or edited."
    end

    KbEvolution::Applier.call(proposal: @proposal)

    redirect_to kb_proposals_path,
                notice: "Applied proposal ##{@proposal.id}. Review with `git diff knowledge_base/` and commit."
  end
end
```

### 6.3 `KbEvolution::Applier` — the file writer

```ruby
# app/services/kb_evolution/applier.rb
module KbEvolution
  class ApplyError < StandardError; end

  class Applier
    ALLOWED_ROOT = Rails.root.join("knowledge_base").to_s

    def self.call(proposal:)
      # Belt-and-braces guardrail against writing outside knowledge_base/.
      # Model validation is one layer; this is the second.
      real_path = proposal.target_pathname.expand_path.to_s
      unless real_path.start_with?(ALLOWED_ROOT + "/")
        raise ApplyError, "Refusing to apply — target_path resolves outside knowledge_base/: #{real_path}"
      end

      case proposal.change_type
      when "edit_snippet"    then apply_edit_snippet(proposal)
      when "append"          then apply_append(proposal)
      when "replace_file"    then apply_replace_file(proposal)
      end

      proposal.update!(status: "applied", applied_at: Time.current)
    end

    def self.apply_edit_snippet(proposal)
      content = File.read(proposal.target_pathname)
      if proposal.old_snippet.blank?
        raise ApplyError, "edit_snippet requires old_snippet"
      end
      unless content.include?(proposal.old_snippet)
        raise ApplyError, "old_snippet not found verbatim in #{proposal.target_path} — reviewer must edit the proposal or reject it"
      end
      # Refuse to apply if old_snippet appears multiple times — ambiguous.
      if content.scan(proposal.old_snippet).size > 1
        raise ApplyError, "old_snippet appears more than once in #{proposal.target_path} — cannot apply unambiguously; reviewer should tighten the snippet"
      end
      new_content = content.sub(proposal.old_snippet, proposal.effective_new_snippet)
      File.write(proposal.target_pathname, new_content)
    end

    def self.apply_append(proposal)
      File.open(proposal.target_pathname, "a") do |f|
        f.puts if !File.read(proposal.target_pathname).end_with?("\n")
        f.puts proposal.effective_new_snippet
      end
    end

    def self.apply_replace_file(proposal)
      # For a brand-new file, target_pathname.parent must exist.
      proposal.target_pathname.dirname.mkpath
      File.write(proposal.target_pathname, proposal.effective_new_snippet)
    end
  end
end
```

**Design note on the three failure modes in `apply_edit_snippet`:** the "not found," "found more
than once," and "requires old_snippet" checks are the mechanical safeguards against Claude's
proposal describing an edit that would apply *somewhere* but not the exact spot Claude reasoned
about. Rather than fuzzy-matching, the applier refuses ambiguous cases and forces the reviewer to
tighten the snippet or reject the proposal — same discipline as `RuleSet#fetch` raising on missing
rules (module 00 §8).

### 6.4 `KbEvolution::AntiRegressionScanner` — surface warnings on `/show`

```ruby
# app/services/kb_evolution/anti_regression_scanner.rb
module KbEvolution
  class AntiRegressionScanner
    def self.call(proposal)
      rules = KnowledgeBase::RuleSet.load("anti_regressions").rules
      flags = []

      combined = "#{proposal.rationale} #{proposal.new_snippet}".downcase

      Array(rules["hard_blocks"]).each do |block|
        indicators = Array(block["pattern_indicators"]).map(&:to_s).map(&:downcase)
        if indicators.any? { |ind| combined.include?(ind) }
          flags << { severity: :hard_block, rule: block["name"], description: block["description"] }
        end
      end

      Array(rules["soft_flags"]).each do |flag|
        # Only one soft flag currently has a mechanical trigger: single_piece_generalisation.
        # replace_file is a UI hint, not a data-driven check.
        if flag["name"] == "single_piece_generalisation"
          pids = proposal.evidence.dig("piece_ids") || []
          if pids.size < 3
            flags << { severity: :warning, rule: flag["name"], description: flag["description"] }
          end
        end
        if flag["name"] == "sweeping_replace_file" && proposal.change_type == "replace_file"
          flags << { severity: :warning, rule: flag["name"], description: flag["description"] }
        end
      end

      flags
    end
  end
end
```

### 6.5 Views

```erb
<%# app/views/kb_proposals/index.html.erb %>
<div class="max-w-5xl mx-auto p-6">
  <h1 class="text-2xl font-semibold mb-4">KB proposals</h1>

  <% if @open_proposals.empty? %>
    <p class="text-gray-500">No open proposals.</p>
  <% else %>
    <div class="space-y-3">
      <% @open_proposals.group_by(&:cycle_id).each do |cycle, proposals| %>
        <div class="border rounded-lg overflow-hidden">
          <div class="bg-gray-100 px-4 py-2 font-mono text-sm">Cycle <%= cycle %> — <%= proposals.size %> open</div>
          <div class="divide-y">
            <% proposals.each do |p| %>
              <%= link_to kb_proposal_path(p), class: "block px-4 py-3 hover:bg-gray-50" do %>
                <div class="font-mono text-sm text-gray-700"><%= p.target_path %></div>
                <div class="text-sm mt-1 text-gray-600"><%= p.rationale.to_s.truncate(160) %></div>
                <div class="text-xs mt-1 text-gray-500"><%= p.change_type %> · evidence: <%= (p.evidence["piece_ids"] || []).size %> piece(s)</div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

```erb
<%# app/views/kb_proposals/show.html.erb %>
<div class="max-w-4xl mx-auto p-6">
  <%= link_to "← Back", kb_proposals_path, class: "text-blue-600 hover:underline" %>

  <h1 class="text-2xl font-semibold mt-2">Proposal ##{@proposal.id}</h1>
  <div class="font-mono text-sm text-gray-600"><%= @proposal.target_path %> · <%= @proposal.change_type %></div>

  <% if @anti_regression_flags.any? %>
    <div class="mt-4 border-l-4 border-yellow-500 bg-yellow-50 p-3">
      <div class="font-semibold text-yellow-800 mb-1">Flags:</div>
      <% @anti_regression_flags.each do |f| %>
        <div class="text-sm text-yellow-900">
          <span class="font-mono text-xs px-1 rounded <%= f[:severity] == :hard_block ? 'bg-red-200' : 'bg-yellow-200' %>"><%= f[:severity] %></span>
          <span class="font-semibold"><%= f[:rule] %></span> — <%= f[:description] %>
        </div>
      <% end %>
    </div>
  <% end %>

  <h2 class="text-lg font-semibold mt-6">Rationale</h2>
  <p class="mt-2 text-gray-800"><%= @proposal.rationale %></p>

  <h2 class="text-lg font-semibold mt-6">Evidence</h2>
  <pre class="bg-gray-50 border rounded p-3 text-xs overflow-auto"><%= JSON.pretty_generate(@proposal.evidence) %></pre>

  <h2 class="text-lg font-semibold mt-6">Proposed change</h2>
  <% if @proposal.change_type == "edit_snippet" %>
    <div class="grid grid-cols-2 gap-3 mt-2">
      <div>
        <div class="text-xs font-semibold text-gray-500 mb-1">CURRENT</div>
        <pre class="bg-red-50 border rounded p-3 text-xs overflow-auto"><%= @proposal.old_snippet %></pre>
      </div>
      <div>
        <div class="text-xs font-semibold text-gray-500 mb-1">PROPOSED</div>
        <pre class="bg-green-50 border rounded p-3 text-xs overflow-auto"><%= @proposal.new_snippet %></pre>
      </div>
    </div>
  <% else %>
    <pre class="bg-green-50 border rounded p-3 text-xs overflow-auto"><%= @proposal.new_snippet %></pre>
  <% end %>

  <%= form_with url: kb_proposal_path(@proposal), method: :patch, local: true, class: "mt-6 space-y-4" do |f| %>
    <div>
      <%= f.label :reviewer_edits, "Counter-proposal (optional)", class: "block text-sm font-medium" %>
      <%= f.text_area :reviewer_edits, rows: 6, class: "mt-1 w-full font-mono text-xs border rounded p-2", placeholder: "Paste your revised new_snippet here to approve-with-edits" %>
    </div>
    <div>
      <%= f.label :reviewer_notes, "Notes", class: "block text-sm font-medium" %>
      <%= f.text_area :reviewer_notes, rows: 3, class: "mt-1 w-full border rounded p-2" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "Approve", name: "decision", value: "approved", class: "bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700" %>
      <%= f.submit "Approve with edits", name: "decision", value: "edited", class: "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" %>
      <%= f.submit "Reject", name: "decision", value: "rejected", class: "bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700" %>
    </div>
  <% end %>

  <% if %w[approved edited].include?(@proposal.status) %>
    <%= button_to "Apply to disk", apply_kb_proposal_path(@proposal), method: :post,
                    class: "mt-4 bg-black text-white px-4 py-2 rounded hover:bg-gray-800" %>
    <p class="text-xs text-gray-500 mt-2">This writes the change to <code><%= @proposal.target_path %></code>. Review with <code>git diff</code> and commit.</p>
  <% end %>
</div>
```

---

## 7. Rake tasks

```ruby
# lib/tasks/evolution.rake
namespace :evolution do
  desc "Refresh performance snapshots for all published pieces. Usage: rake evolution:refresh_stats"
  task refresh_stats: :environment do
    Performance::EtsyStatsFetcher.call(date: Date.current)
    puts "Refreshed snapshots for #{PieceRecord.published.trustworthy.count} published pieces."
  end

  desc "Build the weekly export. Usage: rake evolution:export week_ending=2026-08-24"
  task export: :environment do
    date = ENV["week_ending"] ? Date.parse(ENV["week_ending"]) : Date.current
    result = Performance::WeeklyExport.call(week_ending: date)
    puts "Wrote:"
    puts "  #{result[:markdown_path]}"
    puts "  #{result[:json_path]}"
    puts "Cycle ID: #{result[:cycle_id]}"
    puts "Pieces in window: #{result[:piece_count]}"
    puts "Next: bin/rails evolution:propose cycle=#{result[:cycle_id]}"
  end

  desc "Ask Claude for KB proposals against a cycle. Usage: rake evolution:propose cycle=CYCLE_ID"
  task propose: :environment do
    cycle = ENV.fetch("cycle")
    proposals = KbEvolution::Proposer.call(cycle_id: cycle)
    puts "Claude produced #{proposals.size} proposal(s) for cycle #{cycle}."
    puts "Review at http://localhost:3000/kb_proposals"
  end

  desc "Apply an approved proposal to disk. Usage: rake evolution:apply id=42"
  task apply: :environment do
    p = KbProposal.find(ENV.fetch("id"))
    KbEvolution::Applier.call(proposal: p)
    puts "Applied proposal ##{p.id} to #{p.target_path}."
    puts "Review with: git diff knowledge_base/"
  end
end
```

---

## 8. Verification for this module

```bash
# 1. Migration for kb_proposals ran
bin/rails runner 'puts KbProposal.column_names.size'    # expect 13+

# 2. anti_regressions rule file loads and has all 3 hard-blocks
bin/rails runner '
  r = KnowledgeBase::RuleSet.load("anti_regressions").rules
  puts "hard_blocks: #{r["hard_blocks"].size}"    # expect 3
  puts "soft_flags: #{r["soft_flags"].size}"     # expect 2
  puts "hard_block names: #{r["hard_blocks"].map { |b| b["name"] }.sort}"
'

# 3. KbProposal validates target_path is inside knowledge_base/
bin/rails runner '
  bad = KbProposal.new(cycle_id: "test", target_path: "app/steps/phase2/composite.rb",
                       change_type: "edit_snippet", old_snippet: "x", new_snippet: "y",
                       rationale: "r", opened_at: Time.current)
  puts "rejects app/ target: #{!bad.valid?}"    # expect true
  good = bad.dup
  good.target_path = "knowledge_base/rules/frame_material.yml"
  puts "accepts kb target: #{good.valid?}"      # expect true
'

# 4. Applier refuses paths outside knowledge_base/ even if a bad proposal slipped through
bin/rails runner '
  p = KbProposal.create!(cycle_id: "test", target_path: "knowledge_base/rules/test.yml",
                         change_type: "replace_file", old_snippet: "", new_snippet: "meta:\n  source: test\n  citation: test\n  volatility: static\nrules: {}\n",
                         rationale: "test", opened_at: Time.current, status: "approved")
  begin
    p.update_column(:target_path, "../secret.yml")
    KbEvolution::Applier.call(proposal: p)
    puts "FAIL: applied outside knowledge_base/"
  rescue KbEvolution::ApplyError => e
    puts "rejects escape: ok — #{e.message[0,60]}"
  end
  p.destroy!
'

# 5. edit_snippet refuses ambiguous old_snippet (appears multiple times)
bin/rails runner '
  path = Rails.root.join("knowledge_base/rules/test_ambig.yml")
  File.write(path, "meta:\n  source: t\n  citation: t\n  volatility: static\nrules:\n  x: 1\n  y: 1\n")
  p = KbProposal.create!(cycle_id: "test", target_path: "knowledge_base/rules/test_ambig.yml",
                         change_type: "edit_snippet", old_snippet: "1", new_snippet: "2",
                         rationale: "t", opened_at: Time.current, status: "approved")
  begin
    KbEvolution::Applier.call(proposal: p)
    puts "FAIL: applied ambiguous snippet"
  rescue KbEvolution::ApplyError => e
    puts "rejects ambiguity: ok"
  end
  File.delete(path)
  p.destroy!
'

# 6. AntiRegressionScanner flags a proposal mentioning "renew" in rationale
bin/rails runner '
  p = KbProposal.new(rationale: "we should renew listings weekly",
                     new_snippet: "", change_type: "append",
                     evidence: { "piece_ids" => [1,2,3] },
                     target_path: "knowledge_base/rules/x.yml")
  flags = KbEvolution::AntiRegressionScanner.call(p)
  puts "renewal hard_block: #{flags.any? { |f| f[:rule] == "renewal_chasing" }}"    # expect true
'

# 7. Single-piece proposal fires the soft flag
bin/rails runner '
  p = KbProposal.new(rationale: "clean rationale",
                     new_snippet: "", change_type: "edit_snippet",
                     evidence: { "piece_ids" => [42] },
                     target_path: "knowledge_base/rules/x.yml")
  flags = KbEvolution::AntiRegressionScanner.call(p)
  puts "single-piece warning: #{flags.any? { |f| f[:rule] == "single_piece_generalisation" }}"  # expect true
'

# 8. WeeklyExport excludes dirty:* pieces
bin/rails runner '
  dirty  = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s",
                               kb_version: "dirty:abc", status: "complete",
                               published_at: Date.current)
  clean  = PieceRecord.create!(style_spec_slug: "x", scene_spec_id: "s",
                               kb_version: "abc123", status: "complete",
                               published_at: Date.current)
  window = PieceRecord.published.trustworthy
                      .where(published_at: (Date.current - 6.days).beginning_of_day..Date.current.end_of_day)
  puts "trustworthy excludes dirty: #{window.include?(clean) && !window.include?(dirty)}"    # expect true
  dirty.destroy!; clean.destroy!
'

# 9. Rake tasks registered
bin/rails -T evolution 2>/dev/null | grep -c "evolution:"    # expect 4

# 10. Routes render
bin/rails routes | grep -E "kb_proposals" | head -5
```

**Also verify by hand:**
- The Proposer prompt includes the full text of every rule file in `knowledge_base/rules/` — Claude
  can't propose a well-grounded edit without seeing the current content. Sample size: run
  `bin/rails runner 'puts KbEvolution::Proposer.new(cycle_id: "any").send(:build_kb_snapshot).size'`
  and verify it matches your rule-file count.
- A dirty knowledge-base commit blocks the daily pipeline — this happens automatically because
  `ProcessPieceJob` (module 06 §5.1) calls `PreflightCheck.call!` — but you should verify: after
  Applier writes a change, running the pipeline should refuse until you commit.
- `HumanGate#effective_output` from module 06 §2 is what the Proposer would ideally also consume
  to see what humans overrode. As currently written, `WeeklyExport#piece_summary` includes
  `gate_decisions` but not the full override JSON — if you want Claude to see the actual override
  values (not just approved/rejected), extend `piece_summary` to include
  `g.effective_output`. Small extension; flagged for you to decide before running the first cycle.

---

## 9. Manifest coverage

| Manifest ID | Item | Where |
|---|---|---|
| — | Performance data collection loop (daily fetch → snapshot rows) | §3 |
| — | Weekly export joining PieceRecord + snapshots + gates + kb_version | §4 |
| — | Claude receives current KB files + report; proposes structured edits | §5.1, §5.2 |
| — | Anti-regression safeguards against proposing Etsy anti-patterns | §5.3, §6.4 |
| — | Reviewer surface at `/kb_proposals` with per-proposal approve/reject/edit | §6 |
| — | File writer that refuses paths outside `knowledge_base/` (two guardrail layers) | §2.2 model validation + §6.3 runtime |
| — | Ambiguous-snippet refusal — old_snippet must appear exactly once | §6.3 `apply_edit_snippet` |
| — | Rake tasks for the full weekly cycle | §7 |
| X7 | Style-spec drift warning (from module 04 §6 Limitation 3) | Handled implicitly — the Proposer sees the full spec + rule content and Claude naturally spots drift |
| X8 | Etsy rules are live/changing (from Phase 3 §4) | `WeeklyExport` includes `volatility: live` files by reading via `KnowledgeBase::RuleSet`; the Proposer prompt cites `etsy_antipatterns.yml` explicitly |

**Deferred (per Phase 3 §5):** Performance Tracking as a formal module grounded in *Lean Analytics*
remains deferred — this module provides the mechanical collection loop but not the analytics
framework. When *Lean Analytics* is added to the project knowledge base, its rules can slot in as
a new file that `WeeklyExport` consults for what metrics to prioritize. Nothing in this module
prevents that extension.
