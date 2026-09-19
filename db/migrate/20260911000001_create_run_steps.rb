class CreateRunSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :run_steps do |t|
      t.references :pipeline_run_record, null: false, foreign_key: true
      t.string  :step_id, null: false
      t.integer :position, null: false, default: 0
      t.string  :status, null: false, default: "pending"
      t.text    :summary
      t.jsonb   :output, null: false, default: {}
      t.text    :message
      t.string  :verdict
      t.string  :disposition
      t.string  :reviewer_kind, null: false, default: "human"
      t.jsonb   :escalation, null: false, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :run_steps, %i[pipeline_run_record_id step_id], unique: true
    add_index :run_steps, %i[pipeline_run_record_id position]
  end
end
