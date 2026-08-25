FactoryBot.define do
  factory :kb_proposal do
    cycle_id { "cycle_test" }
    target_path { "knowledge_base/rules/frame_material.yml" }
    change_type { "edit_snippet" }
    old_snippet { "old" }
    new_snippet { "new" }
    rationale { "test rationale" }
    evidence { { "piece_ids" => [1, 2, 3] } }
    status { "open" }
  end
end
