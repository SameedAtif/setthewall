module Schemas
  # Structured interpretation of a reviewer's plain-English feedback on one notebook cell. The
  # interpreter validates the chosen intent against Workflow::DecisionRules before it is applied.
  class FeedbackInterpretationSchema < RubyLLM::Schema
    description "Turn a reviewer's plain-English feedback on a pipeline step into a structured decision."

    string :intent,
           enum: %w[approve edit retry rewind abandon],
           description: "The single decision the reviewer is asking for. approve = accept as-is; " \
                        "edit = accept with the requested changes; retry = run this step again; " \
                        "rewind = go back to an earlier step; abandon = stop the run."
    string :notes,
           description: "A concise, human-readable summary of what the reviewer wants to happen."
    string :reason,
           description: "Why the reviewer wants this; used as the override reason when editing a " \
                        "contradicted result. Empty when not applicable."
    string :edits_json,
           description: "A JSON object (encoded as a string) of field/context values the reviewer " \
                        "asked to change for this step, or \"{}\" when there are no field-level edits."
  end
end
