class AddFulfillmentAndArtIdentityToPieceRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :piece_records, :fulfillment_type, :string
    add_column :piece_records, :chosen_subject,  :string
    add_column :piece_records, :chosen_pattern,  :string
  end
end
