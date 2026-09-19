class AddDecisionOptionsToRunSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :run_steps, :decision_options, :jsonb, null: false, default: []
  end
end
