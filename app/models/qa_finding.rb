class QaFinding < ApplicationRecord
  SEVERITIES = %w[pass advisory blocking].freeze
  ROLES = %w[proposer verifier].freeze

  belongs_to :pipeline_run_record

  validates :severity, inclusion: { in: SEVERITIES }
  validates :role, inclusion: { in: ROLES }

  def blocking? = severity == "blocking"
  def advisory? = severity == "advisory"
  def pass?     = severity == "pass"
end
