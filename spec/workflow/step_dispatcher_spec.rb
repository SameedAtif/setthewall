require "rails_helper"

RSpec.describe Workflow::StepDispatcher do
  it "opens a HumanGate and pauses on awaiting_human" do
    piece = create(:piece_record)
    result = described_class.call(step_id: "P2_7", piece: piece, context: {})

    expect(result).to be_awaiting_human
    expect(piece.reload.status).to eq("awaiting_human")
    expect(piece.current_step).to eq("P2_7")

    gate = piece.open_gate
    expect(gate).to be_present
    expect(gate.status).to eq("open")
    expect(gate.step_id).to eq("P2_7")
  end

  it "raises for an unknown step id" do
    piece = create(:piece_record)
    expect { described_class.call(step_id: "NOPE", piece: piece) }.to raise_error(ArgumentError)
  end

  it "tolerates piece: nil for pre-piece tracks" do
    result = described_class.call(step_id: "P2_7", piece: nil, context: {})
    expect(result).to be_awaiting_human
  end
end
