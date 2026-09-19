class CreateStepFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :step_feedbacks do |t|
      t.references :run_step, null: false, foreign_key: true
      t.string  :role, null: false, default: "human"
      t.text    :body
      t.jsonb   :parsed, null: false, default: {}
      t.boolean :applied, null: false, default: false
      t.timestamps
    end

    add_index :step_feedbacks, %i[run_step_id created_at]
  end
end
