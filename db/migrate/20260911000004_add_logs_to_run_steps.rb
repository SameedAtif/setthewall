class AddLogsToRunSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :run_steps, :logs, :jsonb, null: false, default: []
  end
end
