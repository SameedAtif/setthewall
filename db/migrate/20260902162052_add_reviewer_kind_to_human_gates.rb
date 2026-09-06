class AddReviewerKindToHumanGates < ActiveRecord::Migration[8.0]
  def change
    add_column :human_gates, :reviewer_kind, :string, null: false, default: "human"
    add_column :human_gates, :citations, :jsonb, null: false, default: []
    add_column :human_gates, :verdict, :string
    add_index  :human_gates, :reviewer_kind
    change_column_null :human_gates, :piece_record_id, true
  end
end
