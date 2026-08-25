class PerformanceSnapshot < ApplicationRecord
  belongs_to :piece_record

  validates :captured_on, presence: true
  validates :captured_on, uniqueness: { scope: :piece_record_id }

  def conversion_rate = views.to_i.zero? ? 0.0 : (orders.to_f / views)
end
