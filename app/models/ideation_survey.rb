class IdeationSurvey < ApplicationRecord
  STATUSES = %w[running complete failed].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :complete, -> { where(status: "complete") }

  def running? = status == "running"
  def failed? = status == "failed"
end
