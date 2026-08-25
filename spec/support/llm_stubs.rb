# Shared stubs for RubyLLM.chat and Search::ReasonedRunner.
# Every step class calls `RubyLLM.chat(model:).with_schema(Schema).ask(...).content`.
# These fakes satisfy that chain and let a spec pin the model's returned content —
# either a single `content` for every schema, or a per-schema `contents` mapping.
module LlmStubs
  Message = Struct.new(:content, :tool_call?, keyword_init: true)

  class Chat
    attr_reader :messages, :asked

    def initialize(content:, tool_calls: 0, contents: {})
      @content = content
      @contents = contents
      @schema = nil
      @asked = []
      @messages = Array.new(tool_calls) { Message.new(content: nil, tool_call?: true) }
    end

    def with_schema(schema)
      @schema = schema
      self
    end

    def with_tool(*) = self
    def with_tools(*) = self
    def with_instructions(*) = self
    def with_context(*) = self
    def with_server_tools(*) = self
    def with_temperature(*) = self

    def ask(msg = nil, with: nil, **)
      @asked << { message: msg, with: with }
      @messages << Message.new(content: resolved_content, tool_call?: false)
      @messages.last
    end

    def complete(*) = @messages.last

    private

    def resolved_content
      @contents.key?(@schema) ? @contents[@schema] : @content
    end
  end

  # Stub RubyLLM.chat to return a Chat whose responses come from `content` (or a
  # per-schema `contents` mapping keyed by Schema class). `tool_calls` seeds the
  # message list with tool-call messages (so ReasonedRunner's search guard passes).
  def stub_llm(content: nil, tool_calls: 0, contents: {})
    chat = Chat.new(content: content, tool_calls: tool_calls, contents: contents)
    stub_singleton(RubyLLM, :chat, ->(*_args, **_kwargs) { chat }) do
      yield chat
    end
  end

  # Stub Search::ReasonedRunner.call to return a fixed result without touching the network.
  def stub_reasoned_runner(content:, search_calls_made: 8)
    result = { content: content, search_calls_made: search_calls_made, transcript: [] }
    stub_singleton(Search::ReasonedRunner, :call, ->(**_kwargs) { result }) do
      yield result
    end
  end
end
