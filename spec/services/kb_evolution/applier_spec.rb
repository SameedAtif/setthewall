require "rails_helper"

RSpec.describe KbEvolution::Applier do
  def build_proposal(target_path:, change_type:, old_snippet: "", new_snippet: "new")
    build(:kb_proposal, target_path: target_path, change_type: change_type,
                        old_snippet: old_snippet, new_snippet: new_snippet, status: "approved")
  end

  it "refuses a path that resolves outside knowledge_base/" do
    proposal = create(:kb_proposal, target_path: "knowledge_base/rules/x.yml", change_type: "replace_file", status: "approved")
    proposal.update_column(:target_path, "../secret-#{SecureRandom.hex(4)}.yml")
    expect { described_class.call(proposal: proposal) }.to raise_error(KbEvolution::ApplyError)
  end

  it "refuses an ambiguous old_snippet" do
    path = Rails.root.join("knowledge_base/rules/test_ambig_#{SecureRandom.hex(4)}.yml")
    path.write("meta:\n  source: t\n  citation: t\n  volatility: static\nrules:\n  x: 1\n  y: 1\n")
    track_kb_file(path)

    proposal = build_proposal(target_path: path.relative_path_from(Rails.root).to_s,
                              change_type: "edit_snippet", old_snippet: "1")
    expect { described_class.call(proposal: proposal) }.to raise_error(KbEvolution::ApplyError)
  end

  it "refuses an old_snippet that is not found" do
    path = Rails.root.join("knowledge_base/rules/test_nomatch_#{SecureRandom.hex(4)}.yml")
    path.write("meta:\n  source: t\n  citation: t\n  volatility: static\nrules:\n  x: 1\n")
    track_kb_file(path)

    proposal = build_proposal(target_path: path.relative_path_from(Rails.root).to_s,
                              change_type: "edit_snippet", old_snippet: "not here")
    expect { described_class.call(proposal: proposal) }.to raise_error(KbEvolution::ApplyError)
  end

  it "applies a valid edit_snippet and marks it applied" do
    path = Rails.root.join("knowledge_base/rules/test_edit_#{SecureRandom.hex(4)}.yml")
    path.write("meta:\n  source: t\n  citation: t\n  volatility: static\nrules:\n  x: 1\n")
    track_kb_file(path)

    proposal = build_proposal(target_path: path.relative_path_from(Rails.root).to_s,
                              change_type: "edit_snippet", old_snippet: "x: 1", new_snippet: "x: 2")
    proposal.save!
    described_class.call(proposal: proposal)

    expect(proposal.reload.status).to eq("applied")
    expect(File.read(path)).to include("x: 2")
  end

  it "applies a replace_file to a new path" do
    proposal = build_proposal(target_path: "knowledge_base/rules/test_new_#{SecureRandom.hex(4)}.yml",
                              change_type: "replace_file",
                              new_snippet: "meta:\n  source: t\n  citation: t\n  volatility: static\nrules: {}\n")
    proposal.save!
    track_kb_file(Rails.root.join(proposal.target_path))

    described_class.call(proposal: proposal)
    expect(Rails.root.join(proposal.target_path)).to exist
  end
end
