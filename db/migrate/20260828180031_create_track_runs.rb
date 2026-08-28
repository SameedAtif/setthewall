class CreateTrackRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :track_runs do |t|
      t.string :track, null: false                # track_a | track_b
      t.string :style_slug, null: false
      t.string :scene_template_id                  # track_b only
      t.string :status, null: false, default: "running"  # running | awaiting_human | complete | failed
      t.string :current_step
      t.jsonb  :context, null: false, default: {}  # accumulated inputs threaded across steps
      t.text   :last_error
      t.timestamps
    end

    add_index :track_runs, :status
    add_index :track_runs, [:track, :style_slug]
  end
end
