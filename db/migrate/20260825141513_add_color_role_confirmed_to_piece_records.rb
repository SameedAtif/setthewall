class AddColorRoleConfirmedToPieceRecords < ActiveRecord::Migration[8.0]
  def change
    # Phase 2 Step 4b records the confirmed color role separately from the denormalized
    # spec value (module 00 §9.1's `color_role`). Modules 04 and 05 reference this column.
    add_column :piece_records, :color_role_confirmed, :string
  end
end
