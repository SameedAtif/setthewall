FactoryBot.define do
  factory :piece_record do
    style_spec_slug { "test-style" }
    scene_spec_id { "s1" }
    kb_version { "dirty:test" }
    status { "pending" }

    trait :awaiting_human do
      status { "awaiting_human" }
    end

    trait :complete do
      status { "complete" }
      published_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      last_error { "boom" }
    end
  end
end
