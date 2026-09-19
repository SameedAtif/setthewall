FactoryBot.define do
  factory :step_feedback do
    association :run_step
    role { "human" }
    body { "Please make the mood calmer." }
    parsed { {} }
    applied { false }

    trait :applied do
      applied { true }
    end
  end
end
