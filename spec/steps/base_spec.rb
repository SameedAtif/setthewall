require "rails_helper"

RSpec.describe Steps::Base do
  class OkStep < Steps::Base
    step id: "TEST_OK", mechanism: :lookup, ownership: "[AGENT-READY]"
    def perform = ok({ answer: 42 })
  end

  class HumanStep < Steps::Base
    step id: "TEST_HUMAN", mechanism: :human, ownership: "[HUMAN ONLY]"
    def perform = needs_human("please confirm", { proposed: "x" })
  end

  class FailStep < Steps::Base
    step id: "TEST_FAIL", mechanism: :lookup, ownership: "[AGENT-READY]"
    def perform = fail_step("boom", {})
  end

  it "produces an ok StepResult" do
    result = OkStep.call(piece: create(:piece_record))
    expect(result).to be_ok
    expect(result.data).to eq({ answer: 42 })
  end

  it "produces an awaiting_human StepResult" do
    result = HumanStep.call(piece: create(:piece_record))
    expect(result).to be_awaiting_human
    expect(result.message).to eq("please confirm")
  end

  it "produces a failed StepResult" do
    expect(FailStep.call(piece: create(:piece_record))).to be_failed
  end

  it "logs the outcome to the piece" do
    piece = create(:piece_record)
    OkStep.call(piece: piece)
    expect(piece.reload.step_log.size).to eq(1)
    expect(piece.step_log.first["step_id"]).to eq("TEST_OK")
    expect(piece.step_log.first["outcome"]).to eq("ok")
  end

  it "declares step_id, mechanism, and ownership" do
    expect(OkStep.step_id).to eq("TEST_OK")
    expect(OkStep.mechanism).to eq(:lookup)
    expect(OkStep.ownership).to eq("[AGENT-READY]")
  end

  it "works with piece: nil" do
    expect(HumanStep.call(piece: nil)).to be_awaiting_human
  end
end
