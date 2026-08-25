class CreateHumanGates < ActiveRecord::Migration[8.0]
  def change
    create_table :human_gates do |t|
      t.references :piece_record, null: false, foreign_key: true
      t.string     :step_id,   null: false     # e.g. "P3_2", "A5", "C2"
      t.string     :gate_kind, null: false     # e.g. "confirm_hero_shot", "cull_finalists"
      t.string     :status,    null: false, default: "open"   # open | approved | rejected | edited
      t.text       :agent_proposal              # what the step returned as its suggested answer
      t.text       :reviewer_decision           # what the reviewer chose (may equal proposal)
      t.jsonb      :context_snapshot, null: false, default: {}   # inputs the step was given
      t.jsonb      :reviewer_edits,   null: false, default: {}   # what the reviewer changed, if anything
      t.text       :notes                       # freeform reviewer notes for module 07
      t.datetime   :opened_at
      t.datetime   :closed_at
      t.timestamps
    end

    add_index :human_gates, [:piece_record_id, :status]
    add_index :human_gates, [:step_id, :status]
    add_index :human_gates, :opened_at
  end
end
