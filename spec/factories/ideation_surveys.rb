FactoryBot.define do
  factory :ideation_survey do
    status { "complete" }
    candidates { [] }
    weak_candidates { [] }
  end
end
