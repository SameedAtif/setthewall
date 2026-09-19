require "rails_helper"

RSpec.describe "Steps::Base error handling" do
  class RaisingStep < Steps::Base
    step id: "TEST_RAISE", mechanism: :lookup, ownership: "[AGENT-READY]"
    def perform = raise("kaboom")
  end

  it "marks the piece failed and re-raises" do
    piece = create(:piece_record)
    expect { RaisingStep.call(piece: piece) }.to raise_error(RuntimeError, "kaboom")
    expect(piece.reload.status).to eq("failed")
    expect(piece.last_error).to eq("TEST_RAISE: kaboom")
  end
end

RSpec.describe Workflow::StepDispatcher do
  it "transitions to failed on a failed step result" do
    piece = create(:piece_record)
    result = described_class.call(step_id: "P3_1", piece: piece)
    expect(result).to be_failed
    expect(piece.reload.status).to eq("failed")
    expect(piece.last_error).to include("missing")
  end

  it "marks the piece failed and re-raises on an exception" do
    piece = create(:piece_record)
    stub_singleton(Steps::Base, :call, ->(**_k) { raise "boom" }) do
      expect { described_class.call(step_id: "P2_7", piece: piece) }.to raise_error(RuntimeError, "boom")
    end
    expect(piece.reload.status).to eq("failed")
  end
end

RSpec.describe Search::ReasonedRunner do
  it "prefers server-side search when available" do
    stub_singleton(Pipeline::SearchCapability, :server_side_web_search_available?, -> { true }) do
      stub_llm(content: { "x" => 1 }, tool_calls: 1) do |chat|
        described_class.call(model: "x", schema: Class.new(RubyLLM::Schema), task: "t", question: "q")
        expect(chat).to be_a(LlmStubs::Chat)
      end
    end
  end

  it "fails safe when message introspection raises" do
    stub_llm(content: { "x" => 1 }) do |chat|
      allow(chat).to receive(:messages).and_raise(StandardError)
      expect { described_class.call(model: "x", schema: Class.new(RubyLLM::Schema), task: "t", question: "q") }
        .to raise_error(Search::NoSearchPerformedError)
    end
  end
end

RSpec.describe Pipeline::SearchCapability do
  it "returns false when the runtime check raises" do
    stub_singleton(RubyLLM::Chat, :instance_methods, ->(*) { raise NameError }) do
      expect(described_class.server_side_web_search_available?).to be(false)
    end
  end
end
