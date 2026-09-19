module Schemas
  # AI-generated next-step options for a paused notebook cell. Each option is a concrete decision
  # the reviewer can apply directly; the last free-text route is handled by the UI, not the model.
  class DecisionOptionsSchema < RubyLLM::Schema
    description "Suggest 3-4 concrete next steps a reviewer can take on a paused pipeline step."

    array :options,
          description: "Between 3 and 4 distinct next steps. Only use the legal intents provided." do
      string :label,
             description: "Short imperative label, e.g. 'Approve — continue with Warm minimal'."
      string :description,
             description: "One sentence on what this choice does."
      string :intent,
             enum: %w[approve edit retry rewind abandon],
             description: "The disposition this option performs. Must be one of the legal intents."
      string :notes,
             description: "A short reviewer note explaining the choice."
      string :edits_json,
             description: "A JSON object (as a string) of field values to apply for an 'edit' " \
                          "option, or \"{}\" for the others."
    end
  end
end
