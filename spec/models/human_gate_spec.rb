require "rails_helper"

RSpec.describe HumanGate do
  it "validates status inclusion" do
    gate = build(:human_gate, status: "bogus")
    expect(gate).not_to be_valid
  end

  it "returns the agent proposal on approve" do
    gate = build(:human_gate, status: "approved", agent_proposal: '{"mood":"calm_ordered"}')
    expect(gate.effective_output).to eq({ "mood" => "calm_ordered" })
  end

  it "returns the reviewer decision when present" do
    gate = build(:human_gate, status: "edited", reviewer_decision: '{"mood":"bold_active"}')
    expect(gate.effective_output).to eq({ "mood" => "bold_active" })
  end

  it "returns an empty hash when neither proposal nor decision applies" do
    gate = build(:human_gate, status: "rejected", agent_proposal: nil)
    expect(gate.effective_output).to eq({})
  end

  it "is nil until closed for duration_seconds" do
    gate = build(:human_gate, opened_at: 1.minute.ago)
    expect(gate.duration_seconds).to be_nil
    gate.closed_at = Time.current
    expect(gate.duration_seconds).to be_within(2).of(60)
  end
end
