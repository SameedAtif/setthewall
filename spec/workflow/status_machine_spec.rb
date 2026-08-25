require "rails_helper"

RSpec.describe Workflow::StatusMachine do
  it "rejects an illegal transition" do
    piece = create(:piece_record, :complete)
    expect { described_class.transition!(piece, to: "running") }.to raise_error(Workflow::InvalidTransition)
  end

  it "allows pending → running → awaiting_human → running" do
    piece = create(:piece_record)
    described_class.transition!(piece, to: "running", current_step: "C1")
    expect(piece.reload.status).to eq("running")
    expect(piece.current_step).to eq("C1")

    described_class.transition!(piece, to: "awaiting_human")
    expect(piece.reload.status).to eq("awaiting_human")

    described_class.transition!(piece, to: "running")
    expect(piece.reload.status).to eq("running")
  end

  it "sets last_error only on a failed transition" do
    piece = create(:piece_record, status: "running")
    described_class.transition!(piece, to: "failed", last_error: "boom")
    expect(piece.reload.last_error).to eq("boom")

    piece.update!(status: "running")
    described_class.transition!(piece, to: "pending")
    expect(piece.reload.last_error).to be_nil
  end
end
