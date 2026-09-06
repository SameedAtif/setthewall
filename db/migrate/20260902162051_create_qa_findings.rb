class CreateQaFindings < ActiveRecord::Migration[8.0]
  def change
    create_table :qa_findings do |t|
      t.references :pipeline_run_record, null: false, foreign_key: true
      t.string  :step_id,   null: false
      t.string  :agent_id,  null: false
      t.string  :role,      null: false, default: "proposer"
      t.string  :severity,  null: false
      t.text    :claim,     null: false
      t.jsonb   :citations, null: false, default: []
      t.jsonb   :payload,   null: false, default: {}
      t.boolean :citations_resolved
      t.timestamps
    end
    add_index :qa_findings, [:pipeline_run_record_id, :step_id]
  end
end
