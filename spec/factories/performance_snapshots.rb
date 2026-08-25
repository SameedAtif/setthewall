FactoryBot.define do
  factory :performance_snapshot do
    association :piece_record
    captured_on { Date.current }
    views { 0 }
    favorites { 0 }
    orders { 0 }
    revenue { 0.0 }
  end
end
