require "rails_helper"

RSpec.describe Workflow::DecisionRules do
  Result = Struct.new(:status, :data, :message, keyword_init: true) do
    def failed? = status == :failed
    def awaiting_human? = status == :awaiting_human
  end

  def result(status: :awaiting_human, data: {}, message: nil)
    Result.new(status: status, data: data, message: message)
  end

  describe ".verdict_ids / .disposition_ids" do
    it "exposes the six verdicts and five dispositions" do
      expect(described_class.verdict_ids)
        .to eq(%w[clean flagged unresolved_perception unresolved_input contradicted blocked])
      expect(described_class.disposition_ids).to eq(%w[approve edit retry rewind abandon])
    end
  end

  describe ".legal_dispositions" do
    it "returns the global matrix for a plain verdict" do
      expect(described_class.legal_dispositions(step_id: "A4", verdict: "clean"))
        .to eq(%w[approve edit retry rewind abandon])
    end

    it "forbids approve and edit for unresolved_input" do
      expect(described_class.legal_dispositions(step_id: "A2", verdict: "unresolved_input"))
        .to eq(%w[retry rewind abandon])
    end

    it "lets a step-level override win (P2_3's approve-by-note exception)" do
      expect(described_class.legal_dispositions(step_id: "P2_3", verdict: "unresolved_input"))
        .to eq(%w[approve rewind abandon])
    end
  end

  describe ".tier_for" do
    it "maps the three tiers" do
      expect(described_class.tier_for("A0")).to eq(3)
      expect(described_class.tier_for("A2")).to eq(2)
      expect(described_class.tier_for("C1")).to eq(1)
    end

    it "raises on an unknown step" do
      expect { described_class.tier_for("BOGUS") }.to raise_error(Workflow::DecisionRules::IllegalDisposition)
    end
  end

  describe ".gated_step_ids" do
    it "includes the human-gated steps" do
      ids = described_class.gated_step_ids
      expect(ids).to include("A0", "A2", "A5", "B0", "P2_7", "P3_7")
    end
  end

  describe ".rewind_to" do
    it "returns the rewind target(s)" do
      expect(described_class.rewind_to("A2")).to eq(["A1"])
      expect(described_class.rewind_to("A5")).to eq(%w[A1 A2 A3 A4])
      expect(described_class.rewind_to("A_IDEATE")).to eq([])
    end
  end

  describe ".verdict_for" do
    it "classifies a failed step as blocked" do
      expect(described_class.verdict_for(step_id: "A0", result: result(status: :failed)))
        .to eq("blocked")
    end

    it "classifies return_to_a1 as unresolved_input" do
      expect(described_class.verdict_for(step_id: "A2",
                                         result: result(data: { recommended_action: "return_to_a1" })))
        .to eq("unresolved_input")
    end

    it "classifies reconsider as contradicted" do
      expect(described_class.verdict_for(step_id: "A3",
                                         result: result(data: { recommended_action: "reconsider" })))
        .to eq("contradicted")
    end

    it "classifies confirm as clean" do
      expect(described_class.verdict_for(step_id: "A4",
                                         result: result(data: { recommended_action: "confirm" })))
        .to eq("clean")
    end

    it "classifies a blocking finding as blocked" do
      finding = double("finding", blocking?: true, advisory?: false)
      expect(described_class.verdict_for(step_id: "A2", result: result, findings: [finding]))
        .to eq("blocked")
    end

    it "defaults to clean when the step gives no recommended_action" do
      expect(described_class.verdict_for(step_id: "A4", result: result(data: {}))).to eq("clean")
    end

    it "reads recommended_action from string-keyed data" do
      expect(described_class.verdict_for(step_id: "A2",
                                         result: result(data: { "recommended_action" => "return_to_a1" })))
        .to eq("unresolved_input")
    end
  end

  describe ".validate_disposition!" do
    it "raises on a disposition the verdict forbids" do
      expect {
        described_class.validate_disposition!(step_id: "A2", verdict: "unresolved_input",
                                              disposition: "approve")
      }.to raise_error(Workflow::DecisionRules::IllegalDisposition, /forbids approve/)
    end

    it "refuses an agent closing a Tier 3 gate even with a citation" do
      expect {
        described_class.validate_disposition!(step_id: "A0", verdict: "clean", disposition: "approve",
                                              reviewer_kind: "agent",
                                              payload: { citations: [{ rule_path: "mood.rules" }] })
      }.to raise_error(Workflow::DecisionRules::IllegalDisposition, /Tier 3/)
    end

    it "refuses an agent disposition without a citation" do
      expect {
        described_class.validate_disposition!(step_id: "P3_3", verdict: "clean", disposition: "approve",
                                              reviewer_kind: "agent", payload: { citations: [] })
      }.to raise_error(Workflow::DecisionRules::IllegalDisposition, /no citation/)
    end

    it "requires an acceptance_note to approve a flagged verdict" do
      expect {
        described_class.validate_disposition!(step_id: "A4", verdict: "flagged", disposition: "approve")
      }.to raise_error(Workflow::DecisionRules::IllegalDisposition, /acceptance_note/)
    end

    it "requires an override_reason to edit a contradicted verdict" do
      expect {
        described_class.validate_disposition!(step_id: "A3", verdict: "contradicted", disposition: "edit")
      }.to raise_error(Workflow::DecisionRules::IllegalDisposition, /override_reason/)
    end

    it "accepts a legal human approval" do
      expect(
        described_class.validate_disposition!(step_id: "A4", verdict: "clean", disposition: "approve")
      ).to be(true)
    end
  end
end
