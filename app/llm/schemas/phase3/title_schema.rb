module Schemas
  module Phase3
    class TitleSchema < RubyLLM::Schema
      string :title,
             description: "The full listing title. No price, no emoji, no subjective adjectives, no ALL CAPS."
      string :first_six_words,
             description: "The first 6 words of the title, extracted separately for validation of the descriptor lead."
      boolean :occasion_word_included,
              description: "True only if an occasion/recipient word is present AND the piece is genuinely occasion-specific."
      string :reasoning
    end
  end
end
