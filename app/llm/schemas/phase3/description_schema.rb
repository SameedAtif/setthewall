module Schemas
  module Phase3
    class DescriptionSchema < RubyLLM::Schema
      string :essential_info_block,
             description: "Specs first: dimensions, sizes/variants, what's included, digital vs. physical, turnaround."
      string :engagement_block,
             description: "Story/positioning content, after the essential info."
      string :positioning_claim,
             description: "The specific 'who this is for' sentence. Must be specific, not 'for everyone'."
      array :tag_phrases_used, of: :string,
            description: "Which tag phrases you incorporated in the description. Used to check both presence and non-stuffing."
      string :full_description,
             description: "essential_info_block + engagement_block joined; what actually gets sent to Etsy."
    end
  end
end
