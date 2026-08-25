class CreatePieceRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :piece_records do |t|
      # --- Knowledge-base linkage (files, not FKs — see module 00 §1.1) ---
      t.string :style_spec_slug, null: false
      t.string :scene_spec_id,   null: false
      t.string :kb_version,      null: false   # git SHA, or "dirty:<sha>" for local runs

      # --- Style Spec values, denormalized at run time ---
      # Copied in so a piece stays interpretable even if the spec file later changes.
      t.string :mood
      t.string :content_type
      t.string :frame_form
      t.string :wall_condition
      t.string :furniture_weight
      t.string :room_type
      t.string :room_shape
      t.string :space_math
      t.string :color_role

      # --- Phase 1 Track C ---
      t.integer :batch_count
      t.jsonb   :candidate_urls, null: false, default: []
      t.jsonb   :finalist_urls,  null: false, default: []
      t.string  :chosen_url

      # --- Phase 2 ---
      t.string  :placement_branch          # single | set | split_wall | nook | surface
      t.string  :frame_material_category
      t.string  :frame_material_finish
      t.string  :frame_contour
      t.string  :matting_technique
      t.string  :mat_intensity
      t.string  :arrangement_form
      t.integer :piece_count
      t.string  :anchor_piece_ref
      t.boolean :weight_balance_pass
      t.jsonb   :composite_measurements, null: false, default: {}
      t.string  :composite_url

      # --- Phase 3 ---
      t.jsonb   :photos, null: false, default: {}   # {studio:, lifestyle:, detail:, scale:, group:, packaging:}
      t.jsonb   :photo_order, null: false, default: []
      t.string  :listing_title
      t.jsonb   :listing_tags, null: false, default: []
      t.jsonb   :listing_attributes, null: false, default: {}
      t.string  :listing_category
      t.text    :listing_description
      t.string  :etsy_listing_id
      t.datetime :published_at

      # --- Orchestration ---
      t.string  :status, null: false, default: "pending"
      t.string  :current_step
      t.jsonb   :step_log, null: false, default: []   # append-only audit of every step run
      t.text    :last_error

      t.timestamps
    end

    add_index :piece_records, :status
    add_index :piece_records, :kb_version
    add_index :piece_records, :etsy_listing_id, unique: true
    add_index :piece_records, [:style_spec_slug, :scene_spec_id]
  end
end
