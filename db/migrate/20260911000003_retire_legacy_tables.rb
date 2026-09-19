class RetireLegacyTables < ActiveRecord::Migration[8.0]
  def up
    remove_reference :human_gates, :track_run, foreign_key: true

    drop_table :track_runs do |t|
      t.string   :track, null: false
      t.string   :style_slug, null: false
      t.string   :scene_template_id
      t.string   :status, null: false, default: "running"
      t.string   :current_step
      t.jsonb    :context, null: false, default: {}
      t.text     :last_error
      t.timestamps
      t.index [:status]
      t.index [:track, :style_slug]
    end

    drop_table :kb_proposals do |t|
      t.string   :cycle_id, null: false
      t.string   :target_path, null: false
      t.string   :change_type, null: false
      t.text     :old_snippet
      t.text     :new_snippet, null: false
      t.text     :rationale, null: false
      t.jsonb    :evidence, null: false, default: {}
      t.string   :status, null: false, default: "open"
      t.text     :reviewer_edits
      t.text     :reviewer_notes
      t.datetime :opened_at
      t.datetime :closed_at
      t.datetime :applied_at
      t.timestamps
      t.index [:cycle_id, :status]
      t.index [:status]
      t.index [:target_path]
    end

    drop_table :ideation_surveys do |t|
      t.string   :direction
      t.integer  :candidate_count
      t.string   :status, null: false, default: "complete"
      t.jsonb    :candidates, null: false, default: []
      t.jsonb    :weak_candidates, null: false, default: []
      t.text     :survey_notes
      t.text     :last_error
      t.timestamps
      t.string :progress
      t.index [:created_at]
      t.index [:status]
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Retired tables are not restorable from this migration; restore from a backup."
  end
end
