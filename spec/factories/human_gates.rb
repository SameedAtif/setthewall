FactoryBot.define do
  factory :human_gate do
    association :piece_record
    step_id { "P3_2" }
    gate_kind { "confirm_hero_shot" }
    status { "open" }
    agent_proposal { "{}" }
    context_snapshot { {} }
    reviewer_edits { {} }
    opened_at { Time.current }

    trait :closed do
      status { "approved" }
      closed_at { Time.current }
    end
  end
end
