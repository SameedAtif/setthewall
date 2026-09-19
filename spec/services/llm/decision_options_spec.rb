require "rails_helper"

RSpec.describe Llm::DecisionOptions do
  let(:step) do
    create(:run_step, step_id: "A_IDEATE", status: "awaiting_human",
                      message: "Pick one.", output: { "candidates" => [] })
  end

  before do
    allow(Workflow::DecisionRules).to receive(:legal_dispositions).and_return(%w[approve retry])
  end

  it "returns model options constrained to the legal intents" do
    stub_llm(content: { "options" => [
      { "label" => "Go with A", "description" => "proceed", "intent" => "approve",
        "notes" => "n", "edits_json" => "{}" },
      { "label" => "Illegal", "description" => "x", "intent" => "abandon", "edits_json" => "{}" }
    ] }) do
      options = described_class.call(run_step: step)

      expect(options.map { |o| o["intent"] }).to eq(%w[approve])
      expect(options.first["label"]).to eq("Go with A")
    end
  end

  it "falls back to deterministic options when the model fails" do
    allow(RubyLLM).to receive(:chat).and_raise("boom")

    options = described_class.call(run_step: step)

    expect(options.map { |o| o["intent"] }).to eq(%w[approve retry])
    expect(options.first["label"]).to eq("Approve and continue")
  end
end
