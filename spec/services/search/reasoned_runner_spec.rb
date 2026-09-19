require "rails_helper"

RSpec.describe Search::ReasonedRunner do
  let(:schema) { Class.new(RubyLLM::Schema) }

  it "returns the extracted content with the search count" do
    stub_llm(content: { "summary" => "x", "sources" => [] }, tool_calls: 3) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:content]).to eq({ "summary" => "x", "sources" => [] })
      expect(result[:search_calls_made]).to eq(3)
    end
  end

  it "performs the schema-enforced extraction in a separate tool-free chat" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 1) do |chat|
      described_class.call(model: "x", schema: schema, task: "t", question: "q")
      # Two turns happen: the research ask (the question), then the extraction ask.
      expect(chat.asked.size).to eq(2)
      expect(chat.asked.first[:message]).to eq("q")
      expect(chat.asked.last[:message]).to include("Respond with a SINGLE valid JSON object")
    end
  end

  it "parses a JSON string response into a hash" do
    stub_llm(content: '{"summary":"x"}', tool_calls: 1) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:content]).to eq({ "summary" => "x" })
    end
  end

  it "parses a markdown-fenced JSON response" do
    stub_llm(content: "```json\n{\"summary\":\"x\"}\n```", tool_calls: 1) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:content]).to eq({ "summary" => "x" })
    end
  end

  it "parses a JSON object wrapped in prose" do
    stub_llm(content: "Here are the findings: {\"summary\":\"x\"} hope that helps", tool_calls: 1) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:content]).to eq({ "summary" => "x" })
    end
  end

  it "falls back to an empty hash when the response is not valid JSON" do
    stub_llm(content: "freeform prose with no JSON", tool_calls: 1) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:content]).to eq({})
    end
  end

  it "falls back to an empty hash when the response is blank" do
    stub_llm(content: "", tool_calls: 1) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:content]).to eq({})
    end
  end

  it "falls back to an empty hash when the schema returns a non-object" do
    stub_llm(content: [1, 2, 3], tool_calls: 1) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:content]).to eq({})
    end
  end

  it "raises when the model never searched" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do
      expect { described_class.call(model: "x", schema: schema, task: "t", question: "q") }
        .to raise_error(Search::NoSearchPerformedError)
    end
  end

  it "emits progress through the callback at each checkpoint" do
    messages = []
    stub_llm(content: { "summary" => "x" }, tool_calls: 1) do
      described_class.call(model: "x", schema: schema, task: "t", question: "q",
                           on_progress: ->(message) { messages << message })
    end

    expect(messages).to eq(["researching (live web search, up to 6 searches)",
                            "extracting structured results"])
  end

  it "does not raise when no progress callback is given" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 1) do
      expect { described_class.call(model: "x", schema: schema, task: "t", question: "q") }
        .not_to raise_error
    end
  end

  it "streams when enabled and still returns the extracted content" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 1) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q", stream: true)
      expect(result[:content]).to eq({ "summary" => "x" })
      expect(result[:search_calls_made]).to eq(1)
    end
  end

  it "counts individual tool calls, not tool-call messages" do
    chat = LlmStubs::Chat.new(content: {}, tool_calls: 0)
    msg = LlmStubs::Message.new(content: nil, tool_call?: true, tool_calls: { a: 1, b: 2, c: 3 })
    allow(chat).to receive(:messages).and_return([msg])

    runner = described_class.new(model: "x", schema: schema, task: "t", question: "q")
    expect(runner.send(:count_tool_calls, chat)).to eq(3)
  end

  it "falls back to one per message when tool_calls is not introspectable" do
    chat = LlmStubs::Chat.new(content: {}, tool_calls: 0)
    msg = LlmStubs::Message.new(content: nil, tool_call?: true, tool_calls: nil)
    allow(chat).to receive(:messages).and_return([msg])

    runner = described_class.new(model: "x", schema: schema, task: "t", question: "q")
    expect(runner.send(:count_tool_calls, chat)).to eq(1)
  end

  it "reports min_rounds_met true when the search floor is reached" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 5) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q", min_rounds: 4)
      expect(result[:search_calls_made]).to eq(5)
      expect(result[:min_rounds_met]).to be(true)
    end
  end

  it "reports min_rounds_met false when the search floor is not reached" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 3) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q", min_rounds: 4)
      expect(result[:min_rounds_met]).to be(false)
    end
  end

  it "omits min_rounds_met when no floor is given" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 3) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:min_rounds_met]).to be_nil
    end
  end

  def stub_web_search_tool
    tool = instance_double(Tools::WebSearch)
    allow(Tools::WebSearch).to receive(:new).and_return(tool)
    allow(tool).to receive(:execute)
      .and_return({ results: [{ title: "t", url: "u", snippet: "c" }], images: [] })
    tool
  end

  it "executes scripted queries in code and counts them toward the search total" do
    tool = stub_web_search_tool
    stub_llm(content: { "summary" => "x" }, tool_calls: 2) do |chat|
      result = described_class.call(
        model: "x", schema: schema, task: "t", question: "q",
        scripted: [{ query: "q1", include_images: true, include_domains: ["etsy.com"] }]
      )

      expect(result[:search_calls_made]).to eq(3)
      expect(tool).to have_received(:execute).with(
        query: "q1", include_images: true, include_domains: ["etsy.com"], exclude_domains: []
      )
      expect(chat.asked.first[:message]).to include("already executed")
    end
  end

  it "does not raise when only scripted queries ran" do
    stub_web_search_tool
    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do
      result = described_class.call(
        model: "x", schema: schema, task: "t", question: "q",
        scripted: [{ query: "q1" }]
      )
      expect(result[:search_calls_made]).to eq(1)
    end
  end

  it "raises when neither the model nor scripted queries searched" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do
      expect { described_class.call(model: "x", schema: schema, task: "t", question: "q") }
        .to raise_error(Search::NoSearchPerformedError)
    end
  end
end
