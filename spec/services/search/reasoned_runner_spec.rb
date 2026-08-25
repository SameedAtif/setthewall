require "rails_helper"

RSpec.describe Search::ReasonedRunner do
  let(:schema) { Class.new(RubyLLM::Schema) }

  it "returns the content with the search count" do
    stub_llm(content: { "summary" => "x", "sources" => [] }, tool_calls: 3) do
      result = described_class.call(model: "x", schema: schema, task: "t", question: "q")
      expect(result[:content]).to eq({ "summary" => "x", "sources" => [] })
      expect(result[:search_calls_made]).to eq(3)
    end
  end

  it "raises when the model never searched" do
    stub_llm(content: { "summary" => "x" }, tool_calls: 0) do
      expect { described_class.call(model: "x", schema: schema, task: "t", question: "q") }
        .to raise_error(Search::NoSearchPerformedError)
    end
  end
end
