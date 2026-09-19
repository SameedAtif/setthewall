class PipelineRunRecord < ApplicationRecord
  STATUSES = %w[pending running awaiting_dossier_review approved rerunning committed abandoned failed].freeze
  SCOPES   = %w[style piece full].freeze

  belongs_to :piece_record, optional: true
  has_many :qa_findings, dependent: :destroy
  has_many :run_steps, -> { ordered }, dependent: :destroy, inverse_of: :pipeline_run_record

  validates :status, inclusion: { in: STATUSES }
  validates :scope, inclusion: { in: SCOPES }

  def speculative? = mode == "speculative"
  def awaiting_dossier_review? = status == "awaiting_dossier_review"

  # True while a cell is queued or executing (drives the notebook spinner). Uses a fresh query so
  # a broadcast after a cell finishes never reads a stale cached association.
  def active? = run_steps.where(status: %w[queued running]).exists?

  # Human-facing name: the style plus when the run started. `run_id` stays the internal, unique key.
  def name
    stamp = created_at&.strftime("%b %d, %Y %H:%M") || "unstarted"
    [style_slug.presence || "untitled", stamp].join(" · ")
  end

  # Rebuild `step_results` from the notebook cells. This is the only writer that keeps the legacy
  # jsonb view in sync with `run_steps`; it intentionally reproduces the entry shape written by
  # Conductor#record_step! so existing consumers keep working.
  def mirror_step_results!
    entries = run_steps.reload.ordered.filter_map(&:result_entry)
    update_column(:step_results, entries)
  end
end
