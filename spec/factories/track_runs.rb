FactoryBot.define do
  factory :track_run do
    track { "track_a" }
    style_slug { "test-style" }
    status { "running" }
    context { {} }
  end
end
