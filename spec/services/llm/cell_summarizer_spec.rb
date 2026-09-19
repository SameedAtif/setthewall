require "rails_helper"

RSpec.describe Llm::CellSummarizer do
  let(:step) do
    create(:run_step, step_id: "A0", status: "awaiting_human",
                      output: { "findings" => { "x" => 1 } }, message: "Needs a go/no-go.")
  end

  it "returns the model's prose summary" do
    stub_llm(content: "The style looks viable; review the demand findings.") do
      expect(described_class.call(run_step: step))
        .to eq("The style looks viable; review the demand findings.")
    end
  end

  it "falls back to a deterministic summary when the model fails" do
    allow(RubyLLM).to receive(:chat).and_raise("no api key")

    summary = described_class.call(run_step: step)

    expect(summary).to include("Needs a go/no-go.")
    expect(summary).to include("Findings")
  end
end
