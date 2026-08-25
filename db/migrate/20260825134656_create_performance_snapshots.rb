class CreatePerformanceSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :performance_snapshots do |t|
      t.references :piece_record, null: false, foreign_key: true
      t.date    :captured_on, null: false
      t.integer :views,     default: 0
      t.integer :favorites, default: 0
      t.integer :orders,    default: 0
      t.decimal :revenue, precision: 10, scale: 2, default: 0
      t.jsonb   :search_terms, null: false, default: []  # from Etsy Shop Stats
      t.jsonb   :raw, null: false, default: {}           # untouched API payload
      t.timestamps
    end

    add_index :performance_snapshots, [:piece_record_id, :captured_on], unique: true
  end
end
