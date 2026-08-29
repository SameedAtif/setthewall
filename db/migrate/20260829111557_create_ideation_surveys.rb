class CreateIdeationSurveys < ActiveRecord::Migration[8.0]
  def change
    create_table :ideation_surveys do |t|
      t.string  :direction
      t.integer :candidate_count
      t.string  :status, null: false, default: "complete"  # running | complete | failed
      t.jsonb   :candidates, null: false, default: []
      t.jsonb   :weak_candidates, null: false, default: []
      t.text    :survey_notes
      t.text    :last_error
      t.timestamps
    end

    add_index :ideation_surveys, :status
    add_index :ideation_surveys, :created_at
  end
end
