class HumanGate < ApplicationRecord
  belongs_to :piece_record, optional: true

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
