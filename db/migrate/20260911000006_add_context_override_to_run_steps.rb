class AddContextOverrideToRunSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :run_steps, :context_override, :jsonb, null: false, default: {}
  end
end
