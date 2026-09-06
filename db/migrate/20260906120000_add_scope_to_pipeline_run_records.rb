class AddScopeToPipelineRunRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :pipeline_run_records, :scope, :string, null: false, default: "piece"
  end
end
