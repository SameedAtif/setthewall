require "rails_helper"

RSpec.describe Llm::FeedbackInterpreter do
  let(:step) do
    create(:run_step, step_id: "B3", status: "awaiting_human", output: { "room_type" => "ambiguous" },
                      message: "Classify the room type.")
  end

  it "returns a structured decision" do
    stub_llm(content: {
      "intent" => "edit",
      "notes" => "Treat this as a seated room.",
      "reason" => "The sofa is dominant.",
      "edits_json" => '{"room_type":"seated_room"}'
    }) do
      result = described_class.call(run_step: step, body: "it's clearly a seated room")

      expect(result.intent).to eq("edit")
      expect(result.edits).to eq({ "room_type" => "seated_room" })
      expect(result.reason).to eq("The sofa is dominant.")
    end
  end

  it "accepts edits as a hash" do
    stub_llm(content: {
      "intent" => "edit", "notes" => "ok", "reason" => "",
      "edits_json" => { "room_type" => "hallway" }
    }) do
      expect(described_class.call(run_step: step, body: "hallway").edits)
        .to eq({ "room_type" => "hallway" })
    end
  end

  it "constrains intents to the legal dispositions for the verdict" do
    step.update!(verdict: "unresolved_input")
    allow(Workflow::DecisionRules).to receive(:legal_dispositions)
      .with(step_id: "B3", verdict: "unresolved_input")
      .and_return(%w[retry rewind abandon])

    stub_llm(content: { "intent" => "approve", "notes" => "", "reason" => "", "edits_json" => "{}" }) do
      expect { described_class.call(run_step: step, body: "looks fine") }
        .to raise_error(Llm::FeedbackInterpreter::IllegalIntent, /not legal/)
    end
  end

  it "raises on an unknown intent" do
    stub_llm(content: { "intent" => "banana", "notes" => "", "reason" => "", "edits_json" => "{}" }) do
      expect { described_class.call(run_step: step, body: "??") }
        .to raise_error(Llm::FeedbackInterpreter::IllegalIntent)
    end
  end
end
