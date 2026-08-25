class KbProposal < ApplicationRecord
  STATUSES = %w[open approved rejected edited applied].freeze
  CHANGE_TYPES = %w[edit_snippet append replace_file].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :change_type, inclusion: { in: CHANGE_TYPES }
  # First-pass guard. The real traversal defense is KbEvolution::Applier's
  # expand_path + start_with?(ALLOWED_ROOT) check at write time; this regex just
  # rejects obviously out-of-tree targets early.
  validates :target_path, format: { with: %r{\Aknowledge_base/.*\z} }

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
