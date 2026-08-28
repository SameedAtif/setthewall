class AddTrackRunToHumanGates < ActiveRecord::Migration[8.0]
  def change
    # Track A/B run pre-piece, so their gates aren't tied to a PieceRecord.
    change_column_null :human_gates, :piece_record_id, true
    add_reference :human_gates, :track_run, foreign_key: true, null: true
  end
end
