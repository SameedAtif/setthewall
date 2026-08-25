require "test_helper"

class KbProposalTest < ActiveSupport::TestCase
  test "rejects a target_path outside knowledge_base/" do
    proposal = KbProposal.new(cycle_id: "c", target_path: "app/models/piece_record.rb",
                              change_type: "edit_snippet", old_snippet: "x", new_snippet: "y",
                              rationale: "r", status: "open")
    assert_not proposal.valid?
    assert_includes proposal.errors[:target_path], "is invalid"
  end

  test "accepts a target_path inside knowledge_base/" do
    proposal = KbProposal.new(cycle_id: "c", target_path: "knowledge_base/rules/frame_material.yml",
                              change_type: "edit_snippet", old_snippet: "x", new_snippet: "y",
                              rationale: "r", status: "open")
    assert proposal.valid?
  end

  test "effective_new_snippet prefers reviewer edits" do
    proposal = KbProposal.new(new_snippet: "claude", status: "edited", reviewer_edits: "reviewer")
    assert_equal "reviewer", proposal.effective_new_snippet

    proposal.status = "approved"
    assert_equal "claude", proposal.effective_new_snippet
  end

  test "validates change_type inclusion" do
    proposal = KbProposal.new(cycle_id: "c", target_path: "knowledge_base/rules/x.yml",
                              change_type: "nonsense", new_snippet: "y", rationale: "r")
    assert_not proposal.valid?
  end
end
