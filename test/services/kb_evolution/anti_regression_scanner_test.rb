require "test_helper"

class AntiRegressionScannerTest < ActiveSupport::TestCase
  test "flags a proposal mentioning 'renew' as a hard block" do
    proposal = KbProposal.new(rationale: "we should renew listings weekly", new_snippet: "",
                              change_type: "append", evidence: { "piece_ids" => [1, 2, 3] })
    flags = KbEvolution::AntiRegressionScanner.call(proposal)
    assert flags.any? { |f| f[:rule] == "renewal_chasing" && f[:severity] == :hard_block }
  end

  test "flags a single-piece proposal as a warning" do
    proposal = KbProposal.new(rationale: "clean rationale", new_snippet: "",
                              change_type: "edit_snippet", evidence: { "piece_ids" => [42] })
    flags = KbEvolution::AntiRegressionScanner.call(proposal)
    assert flags.any? { |f| f[:rule] == "single_piece_generalisation" && f[:severity] == :warning }
  end

  test "flags a replace_file proposal as a warning" do
    proposal = KbProposal.new(rationale: "clean", new_snippet: "",
                              change_type: "replace_file", evidence: { "piece_ids" => [1, 2, 3] })
    flags = KbEvolution::AntiRegressionScanner.call(proposal)
    assert flags.any? { |f| f[:rule] == "sweeping_replace_file" && f[:severity] == :warning }
  end

  test "returns no flags for a clean, multi-piece proposal" do
    proposal = KbProposal.new(rationale: "clean", new_snippet: "clean",
                              change_type: "edit_snippet", evidence: { "piece_ids" => [1, 2, 3] })
    assert_empty KbEvolution::AntiRegressionScanner.call(proposal)
  end
end
