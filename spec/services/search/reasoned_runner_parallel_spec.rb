require "rails_helper"

RSpec.describe Search::ReasonedRunner do
  let(:schema) { Class.new(RubyLLM::Schema) }

  # A web-search double whose `execute` behaviour is driven by the query, and which records the
  # maximum number of concurrently in-flight searches so we can prove parallelism.
  def parallel_probe(behaviour)
    mutex = Mutex.new
    state = { current: 0, max: 0 }
    klass = Class.new do
      define_method(:execute) do |query:, **|
        mutex.synchronize do
          state[:current] += 1
          state[:max] = [state[:max], state[:current]].max
        end
        sleep 0.05
        result = behaviour.call(query)
        mutex.synchronize { state[:current] -= 1 }
        result
      end
    end
    [klass.new, state]
  end

  def success(query = "t")
    { results: [{ title: query, url: "https://example.com/#{query}", snippet: "c" }], images: [] }
  end

  it "runs scripted queries concurrently" do
    tool, state = parallel_probe(->(query) { success(query) })
    allow(Tools::WebSearch).to receive(:new).and_return(tool)

    stub_llm(content: { "summary" => "x" }, tool_calls: 1) do
      described_class.call(model: "x", schema: schema, task: "t", question: "q",
                           scripted: [{ query: "q1" }, { query: "q2" }, { query: "q3" }])
    end

    expect(state[:max]).to be >= 2
  end

  it "injects scripted evidence in query order despite concurrent completion" do
    tool, = parallel_probe(->(query) { success(query) })
    allow(Tools::WebSearch).to receive(:new).and_return(tool)

    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do |chat|
      described_class.call(model: "x", schema: schema, task: "t", question: "q",
                           scripted: [{ query: "q1" }, { query: "q2" }, { query: "q3" }])

      message = chat.asked.first[:message]
      expect(message.index("q1")).to be < message.index("q2")
      expect(message.index("q2")).to be < message.index("q3")
    end
  end

  it "proceeds when some scripted searches fail" do
    tool, = parallel_probe(->(query) { query == "bad" ? { error: "boom", query: query } : success(query) })
    allow(Tools::WebSearch).to receive(:new).and_return(tool)

    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do |chat|
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q",
                                    scripted: [{ query: "ok" }, { query: "bad" }])

      expect(result[:search_calls_made]).to eq(2)
      expect(chat.asked.first[:message]).to include("attempted but returned no evidence")
    end
  end

  it "raises when every scripted search fails" do
    tool, = parallel_probe(->(query) { { error: "boom", query: query } })
    allow(Tools::WebSearch).to receive(:new).and_return(tool)

    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do
      expect {
        described_class.call(model: "x", schema: schema, task: "t", question: "q",
                             scripted: [{ query: "a" }, { query: "b" }])
      }.to raise_error(Search::NoSearchPerformedError, /failed or timed out/)
    end
  end

  it "records a timeout without hanging and proceeds when another search succeeded" do
    ENV["SEARCH_TIMEOUT_SECONDS"] = "0.2"
    tool, = parallel_probe(lambda { |query|
      if query == "slow"
        sleep 0.5
        success(query)
      else
        success(query)
      end
    })
    allow(Tools::WebSearch).to receive(:new).and_return(tool)

    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q",
                                    scripted: [{ query: "fast" }, { query: "slow" }])

      expect(result[:search_calls_made]).to eq(2)
      expect(result[:searches].any? { |s| (s[:error] || s["error"]).to_s.include?("timed out") })
        .to be(true)
    end
  ensure
    ENV.delete("SEARCH_TIMEOUT_SECONDS")
  end

  it "streams per-search progress through the step log" do
    tool, = parallel_probe(->(query) { success(query) })
    allow(Tools::WebSearch).to receive(:new).and_return(tool)
    messages = []

    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do
      Workflow::StepLogging.with_logger(->(message, level:) { messages << [message, level] }) do
        described_class.call(model: "x", schema: schema, task: "t", question: "q",
                             scripted: [{ query: "q1" }, { query: "q2" }])
      end
    end

    expect(messages.count { |m, _| m.start_with?("search started:") }).to eq(2)
    expect(messages.count { |m, _| m.start_with?("search done:") }).to eq(2)
    expect(messages.map(&:first)).to include(a_string_matching(/searches complete: 2 ok/))
  end
end
