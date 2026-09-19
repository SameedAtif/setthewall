require "rails_helper"

RSpec.describe Pipeline::Streaming do
  # Minimal chat double: yields `chunks` callbacks, then returns `result`.
  def streaming_chat(chunks:, result:)
    Class.new do
      attr_reader :messages

      define_method(:initialize) do
        @messages = []
        @chunks = chunks
        @result = result
      end

      define_method(:ask) do |_prompt, with: nil, &block|
        @chunks.times { block&.call("chunk") }
        @result
      end
    end.new
  end

  it "returns the message while chunks flow" do
    chat = streaming_chat(chunks: 3, result: :the_message)

    expect(described_class.ask(chat, "prompt", stall_seconds: 1, attempts: 1)).to eq(:the_message)
  end

  it "forwards attached images to the chat" do
    received = nil
    chat = Class.new do
      attr_reader :messages

      define_method(:initialize) { @messages = [] }
      define_method(:ask) do |_prompt, with: nil, &block|
        received = with
        block&.call("chunk")
        :ok
      end
    end.new

    described_class.ask(chat, "p", with: ["img.png"], stall_seconds: 1, attempts: 1)

    expect(received).to eq(["img.png"])
  end

  it "retries a stalled call and returns when a later attempt makes progress" do
    calls = 0
    chat = Class.new do
      attr_reader :messages

      define_method(:initialize) { @messages = [] }

      define_method(:ask) do |_prompt, with: nil, &block|
        calls += 1
        sleep 30 if calls == 1
        2.times { block&.call("chunk") }
        :ok
      end
    end.new

    expect(described_class.ask(chat, "p", stall_seconds: 0.2, attempts: 2)).to eq(:ok)
  end

  it "raises Stalled after every attempt stalls" do
    chat = Class.new do
      attr_reader :messages

      define_method(:initialize) { @messages = [] }
      define_method(:ask) { |_prompt, with: nil, &_block| sleep 30 }
    end.new

    expect { described_class.ask(chat, "p", stall_seconds: 0.2, attempts: 2) }
      .to raise_error(Pipeline::Streaming::Stalled, /no stream data/)
  end
end
