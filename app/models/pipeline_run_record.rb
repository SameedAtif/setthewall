class PipelineRunRecord < ApplicationRecord
  STATUSES = %w[running awaiting_dossier_review approved rerunning committed abandoned failed].freeze

  belongs_to :piece_record, optional: true
  has_many :qa_findings, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  def speculative? = mode == "speculative"
  def awaiting_dossier_review? = status == "awaiting_dossier_review"
end
