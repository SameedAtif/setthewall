module KbEvolution
  class ProposalListSchema < RubyLLM::Schema
    integer :proposal_count,
            description: "How many proposals below. Zero is a legitimate answer if the data doesn't justify any."
    array :proposals do
      object do
        string :target_path,
               description: "Path relative to Rails root — must start with 'knowledge_base/'"
        string :change_type,
               enum: %w[edit_snippet append replace_file],
               description: "'edit_snippet' replaces exact old_snippet with new_snippet. 'append' adds new_snippet to end of file. 'replace_file' overwrites the whole file (use sparingly)."
        string :old_snippet,
               description: "Exact text to be replaced. Required for edit_snippet; empty for append; full current file for replace_file."
        string :new_snippet,
               description: "The replacement text. Required."
        string :rationale,
               description: "Must cite specific pieces or aggregate metrics from the report. No hand-waving."
        object :evidence do
          array :piece_ids, of: :integer, description: "Piece IDs supporting the change"
          array :listing_ids, of: :string, description: "Etsy listing IDs supporting the change"
          object :metrics, description: "Specific numbers cited" do; end
        end
      end
    end
    string :summary_notes,
           description: "Overall reading of the week — the data-was-sparse case goes here."
  end
end
