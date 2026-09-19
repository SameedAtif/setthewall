class StepFeedback < ApplicationRecord
  ROLES = %w[human assistant system].freeze

  belongs_to :run_step

  validates :role, inclusion: { in: ROLES }
  validates :body, presence: true

  scope :applied, -> { where(applied: true) }

  def human?     = role == "human"
  def assistant? = role == "assistant"
  def system?    = role == "system"
end
