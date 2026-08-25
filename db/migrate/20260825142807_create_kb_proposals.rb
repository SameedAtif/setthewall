class CreateKbProposals < ActiveRecord::Migration[8.0]
  def change
    create_table :kb_proposals do |t|
      t.string  :cycle_id,   null: false                   # groups proposals from one Claude call
      t.string  :target_path, null: false                   # e.g. "knowledge_base/rules/etsy_tags.yml"
      t.string  :change_type, null: false                   # edit_snippet | append | replace_file
      t.text    :old_snippet                                # what was there (empty for append)
      t.text    :new_snippet, null: false                   # what Claude proposes
      t.text    :rationale,   null: false                   # Claude's grounding — must cite performance data
      t.jsonb   :evidence, null: false, default: {}         # {piece_ids: [], listing_ids: [], metrics: {}}
      t.string  :status,      null: false, default: "open"  # open | approved | rejected | edited | applied
      t.text    :reviewer_edits                             # the reviewer's counter-proposed new_snippet
      t.text    :reviewer_notes                             # freeform reasoning for module 07's own audit
      t.datetime :opened_at
      t.datetime :closed_at
      t.datetime :applied_at
      t.timestamps
    end

    add_index :kb_proposals, [:cycle_id, :status]
    add_index :kb_proposals, :target_path
    add_index :kb_proposals, :status
  end
end
