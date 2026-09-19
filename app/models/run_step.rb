class RunStep < ApplicationRecord
  STATUSES = %w[pending queued running awaiting_human done stale failed skipped].freeze

  # Cell status → the status string Conductor#record_step! writes into
  # PipelineRunRecord#step_results. Statuses absent here (pending/running/stale/skipped) are not
  # mirrored — they have no committed run result yet.
  RESULT_STATUSES = {
    "done"           => "ok",
    "awaiting_human" => "awaiting_human",
    "failed"         => "failed"
  }.freeze

  belongs_to :pipeline_run_record
  has_many :step_feedbacks, -> { order(:created_at, :id) }, dependent: :destroy

  validates :step_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :step_id, uniqueness: { scope: :pipeline_run_record_id }

  scope :ordered, -> { order(:position, :id) }

  after_save :mirror_to_run

  def pending?        = status == "pending"
  def queued?         = status == "queued"
  def running?        = status == "running"
  def awaiting_human? = status == "awaiting_human"
  def done?           = status == "done"
  def stale?          = status == "stale"
  def failed?         = status == "failed"
  def skipped?        = status == "skipped"

  def terminal? = %w[done failed skipped].include?(status)

  # Mood clusters the A1 reference set spans (labels only). More than one means the set has
  # stylistic variation; whether that is a problem depends on the reconciliation.
  def mood_clusters
    Array(output.dig("candidates", "mood_clusters_found")).filter_map do |cluster|
      cluster["label"] if cluster.is_a?(Hash)
    end
  end

  # A1's post-reconciliation dominant mood (calm_ordered / bold_active / mixed), if reported.
  def dominant_mood = output.dig("candidates", "dominant_mood").presence

  def shared_qualities = Array(output.dig("candidates", "shared_qualities"))

  # True only when the reference set spans camps that could NOT be reconciled into one mood.
  # Legacy cells without a dominant_mood fall back to "any split is unresolved" for display, but
  # are still re-runnable once so they can pick up the reconciliation.
  def mood_unresolved?
    return false if mood_clusters.size <= 1

    dominant_mood.blank? || dominant_mood == "mixed" || shared_qualities.empty?
  end

  # True when A1 explicitly reported that the camps could not be reconciled.
  def mood_mixed? = mood_clusters.size > 1 && dominant_mood == "mixed"

  # Append a timestamped line to this cell's log. Uses update_column so logging never triggers the
  # step_results mirror or validations; callers broadcast the change themselves.
  def log!(message, level: "info")
    entry = { "at" => Time.current.iso8601, "level" => level.to_s, "message" => message.to_s }
    update_column(:logs, Array(logs) + [entry])
    entry
  end

  # The exact shape Conductor#record_step! produces, so mirroring cells into
  # `PipelineRunRecord#step_results` keeps Context::Assembler, Dossier::Builder and
  # DecisionRules working unchanged.
  def result_entry
    result_status = RESULT_STATUSES[status]
    return nil if result_status.nil?

    entry = {
      "step_id" => step_id,
      "status"  => result_status,
      "data"    => (output || {}).stringify_keys
    }
    entry["message"]     = message     if message.present?
    entry["verdict"]     = verdict     if verdict.present?
    entry["disposition"] = disposition if disposition.present?
    entry
  end

  private

  def mirror_to_run
    pipeline_run_record.mirror_step_results!
  end
end
