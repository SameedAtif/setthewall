FactoryBot.define do
  factory :pipeline_run_record do
    sequence(:run_id) { |n| "run_test_#{n}" }
    mode { "speculative" }
    status { "running" }
    scope { "full" }
    kb_version { "dirty:test" }
    step_results { [] }
    escalations { [] }
    dossier_data { {} }
  end
end
