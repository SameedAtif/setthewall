require "rails_helper"

RSpec.describe KbEvolution::AntiRegressionScanner do
  it "flags a proposal mentioning 'renew' as a hard block" do
    proposal = build(:kb_proposal, rationale: "we should renew listings weekly", new_snippet: "")
    flags = described_class.call(proposal)
    expect(flags).to include(hash_including(rule: "renewal_chasing", severity: :hard_block))
  end

  it "flags a single-piece proposal as a warning" do
    proposal = build(:kb_proposal, evidence: { "piece_ids" => [42] })
    flags = described_class.call(proposal)
    expect(flags).to include(hash_including(rule: "single_piece_generalisation", severity: :warning))
  end

  it "flags a replace_file proposal as a warning" do
    proposal = build(:kb_proposal, change_type: "replace_file")
    flags = described_class.call(proposal)
    expect(flags).to include(hash_including(rule: "sweeping_replace_file", severity: :warning))
  end

  it "returns no flags for a clean, multi-piece proposal" do
    proposal = build(:kb_proposal, rationale: "clean", new_snippet: "clean")
    expect(described_class.call(proposal)).to be_empty
  end
end
