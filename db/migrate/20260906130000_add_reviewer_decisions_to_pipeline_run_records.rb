class AddReviewerDecisionsToPipelineRunRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :pipeline_run_records, :reviewer_decisions, :jsonb, null: false, default: {}
  end
end
