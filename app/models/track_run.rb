class TrackRun < ApplicationRecord
  TRACKS = %w[track_a track_b].freeze
  STATUSES = %w[running awaiting_human complete failed].freeze

  has_many :human_gates, dependent: :destroy

  validates :track, inclusion: { in: TRACKS }
  validates :style_slug, presence: true
  validates :status, inclusion: { in: STATUSES }

  def complete? = status == "complete"
  def failed? = status == "failed"
  def awaiting_human? = status == "awaiting_human"
end
