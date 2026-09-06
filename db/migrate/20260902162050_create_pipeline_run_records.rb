class CreatePipelineRunRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :pipeline_run_records do |t|
      t.string   :run_id,   null: false, index: { unique: true }
      t.string   :mode,     null: false, default: "speculative"
      t.string   :status,   null: false, default: "running"
      t.references :piece_record, foreign_key: true
      t.string   :style_slug
      t.string   :scene_spec_id
      t.string   :kb_version, null: false
      t.jsonb    :step_results,  null: false, default: []
      t.jsonb    :escalations,   null: false, default: []
      t.text     :dossier_markdown
      t.jsonb    :dossier_data,  null: false, default: {}
      t.text     :reviewer_notes
      t.datetime :started_at
      t.datetime :dossier_ready_at
      t.datetime :reviewed_at
      t.timestamps
    end
  end
end
