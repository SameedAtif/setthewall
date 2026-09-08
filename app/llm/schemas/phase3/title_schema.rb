module Schemas
  module Phase3
    class TitleSchema < RubyLLM::Schema
      string :title,
             description: "The full listing title. No price, no emoji, no subjective adjectives, no ALL CAPS."
      boolean :occasion_word_included,
              description: "True only if an occasion/recipient word is present AND the piece is genuinely occasion-specific."
      string :reasoning
    end
  end
end
