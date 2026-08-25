require "test_helper"

class KbEvolutionApplierTest < ActiveSupport::TestCase
  def build_proposal(target_path:, change_type:, old_snippet: "", new_snippet: "new")
    KbProposal.new(cycle_id: "c-#{SecureRandom.hex(4)}", target_path: target_path,
                   change_type: change_type, old_snippet: old_snippet,
                   new_snippet: new_snippet, rationale: "r", status: "approved")
  end

  test "refuses a path that resolves outside knowledge_base/" do
    proposal = KbProposal.create!(cycle_id: "c", target_path: "knowledge_base/rules/x.yml",
                                  change_type: "replace_file", new_snippet: "n", rationale: "r",
                                  status: "approved")
    # Bypass model validation to exercise the Applier's runtime guard directly.
    proposal.update_column(:target_path, "../secret-#{SecureRandom.hex(4)}.yml")
    assert_raises(KbEvolution::ApplyError) { KbEvolution::Applier.call(proposal: proposal) }
  end

  test "refuses an ambiguous old_snippet" do
    path = Rails.root.join("knowledge_base/rules/test_ambig_#{SecureRandom.hex(4)}.yml")
    path.write("meta:\n  source: t\n  citation: t\n  volatility: static\nrules:\n  x: 1\n  y: 1\n")
    track_kb_file(path)

    proposal = build_proposal(target_path: path.relative_path_from(Rails.root).to_s,
                              change_type: "edit_snippet", old_snippet: "1")
    assert_raises(KbEvolution::ApplyError) { KbEvolution::Applier.call(proposal: proposal) }
  end

  test "refuses an old_snippet that is not found" do
    path = Rails.root.join("knowledge_base/rules/test_nomatch_#{SecureRandom.hex(4)}.yml")
    path.write("meta:\n  source: t\n  citation: t\n  volatility: static\nrules:\n  x: 1\n")
    track_kb_file(path)

    proposal = build_proposal(target_path: path.relative_path_from(Rails.root).to_s,
                              change_type: "edit_snippet", old_snippet: "not here")
    assert_raises(KbEvolution::ApplyError) { KbEvolution::Applier.call(proposal: proposal) }
  end

  test "applies a valid edit_snippet and marks it applied" do
    path = Rails.root.join("knowledge_base/rules/test_edit_#{SecureRandom.hex(4)}.yml")
    path.write("meta:\n  source: t\n  citation: t\n  volatility: static\nrules:\n  x: 1\n")
    track_kb_file(path)

    proposal = build_proposal(target_path: path.relative_path_from(Rails.root).to_s,
                              change_type: "edit_snippet", old_snippet: "x: 1", new_snippet: "x: 2")
    proposal.save!
    KbEvolution::Applier.call(proposal: proposal)

    assert_equal "applied", proposal.reload.status
    assert_includes File.read(path), "x: 2"
  end

  test "applies a replace_file to a new path" do
    proposal = build_proposal(target_path: "knowledge_base/rules/test_new_#{SecureRandom.hex(4)}.yml",
                              change_type: "replace_file",
                              new_snippet: "meta:\n  source: t\n  citation: t\n  volatility: static\nrules: {}\n")
    proposal.save!
    track_kb_file(Rails.root.join(proposal.target_path))

    KbEvolution::Applier.call(proposal: proposal)
    assert File.exist?(Rails.root.join(proposal.target_path))
  end
end
