require "test_helper"

class KbProposalsControllerTest < ActionDispatch::IntegrationTest
  def build_proposal(status: "open", rationale: "clean rationale", change_type: "append")
    KbProposal.create!(cycle_id: "cycle_test", target_path: "knowledge_base/rules/x.yml",
                       change_type: change_type, new_snippet: "new: true",
                       rationale: rationale, evidence: { "piece_ids" => [1, 2, 3] },
                       status: status, opened_at: Time.current)
  end

  test "index lists open proposals" do
    build_proposal
    get kb_proposals_path
    assert_response :success
    assert_match(/knowledge_base\/rules\/x.yml/, response.body)
  end

  test "show renders rationale and flags anti-regression proposals" do
    proposal = build_proposal(rationale: "we should renew listings weekly")
    get kb_proposal_path(proposal)
    assert_response :success
    assert_match(/renewal_chasing/, response.body)
  end

  test "update marks a proposal approved" do
    proposal = build_proposal
    patch kb_proposal_path(proposal), params: { decision: "approved" }
    assert_redirected_to kb_proposals_path
    assert_equal "approved", proposal.reload.status
  end

  test "apply refuses a proposal that is not approved or edited" do
    proposal = build_proposal(status: "open")
    post apply_kb_proposal_path(proposal)
    assert_redirected_to kb_proposals_path
    assert_equal "open", proposal.reload.status
  end
end
