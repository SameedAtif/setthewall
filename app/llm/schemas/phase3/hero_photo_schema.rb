module Schemas
  module Phase3
    class HeroPhotoSchema < RubyLLM::Schema
      string :recommended_hero,
             description: "The photo type (studio, lifestyle, detail, …) recommended as position 1"
      string :reasoning,
             description: "Why this one is the clearest and most eye-catching — not why it's the most artistic."
      array :ordering, of: :string,
            description: "Full recommended photo order, hero first, up to 10 slots."
      integer :photo_count
    end
  end
end
