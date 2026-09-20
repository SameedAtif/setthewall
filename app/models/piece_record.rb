class PieceRecord < ApplicationRecord
  has_many :performance_snapshots, dependent: :destroy
  has_many :human_gates, dependent: :destroy

  STATUSES = %w[pending running awaiting_human complete failed].freeze

  validates :style_spec_slug, :scene_spec_id, :kb_version, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :awaiting_human, -> { where(status: "awaiting_human") }
  scope :published,      -> { where.not(published_at: nil) }
  scope :trustworthy,    -> { where.not("kb_version LIKE 'dirty:%'") }

  def style_spec = KnowledgeBase::StyleSpec.load(style_spec_slug)
  def scene_spec = style_spec.scene(scene_spec_id)

  def dirty_run? = kb_version.to_s.start_with?("dirty:")

  def open_gate = human_gates.open.order(:opened_at).last

  def gate_history(step_id: nil)
    scope = human_gates.order(:opened_at)
    step_id ? scope.where(step_id: step_id) : scope
  end

  # Copy the nine axis values in at creation time.
  def apply_spec!(spec, scene)
    assign_attributes(
      mood: spec.style_level[:mood],
      content_type: spec.style_level[:content_type],
      frame_form: spec.style_level[:frame_form],
      wall_condition: scene.wall_condition,
      furniture_weight: scene.furniture_weight,
      room_type: scene.room_type,
      room_shape: scene.room_shape,
      space_math: scene.space_math,
      # Color role is a style-level observation (A1b reference essence), not a scene axis.
      color_role: spec.reference_essence["color_role"],
      fulfillment_type: spec.production_model["fulfillment_type"]
    )
  end

  def log_step!(step_id:, mechanism:, outcome:, detail: {})
    self.step_log = step_log + [{
      step_id:, mechanism:, outcome:, detail:,
      at: Time.current.iso8601
    }]
    save!
  end
end
