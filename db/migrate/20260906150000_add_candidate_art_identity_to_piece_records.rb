class AddCandidateArtIdentityToPieceRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :piece_records, :candidate_subjects, :jsonb, null: false, default: []
    add_column :piece_records, :candidate_patterns, :jsonb, null: false, default: []
  end
end
