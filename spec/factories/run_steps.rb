FactoryBot.define do
  factory :run_step do
    association :pipeline_run_record
    sequence(:step_id) { |n| "STEP_#{n}" }
    position { 0 }
    status { "pending" }
    output { {} }
    reviewer_kind { "human" }
    escalation { {} }

    trait :done do
      status { "done" }
      output { { "result" => "ok" } }
      finished_at { Time.current }
    end

    trait :awaiting_human do
      status { "awaiting_human" }
      message { "Needs your review." }
    end

    trait :stale do
      status { "stale" }
    end

    trait :failed do
      status { "failed" }
      message { "boom" }
    end
  end
end
