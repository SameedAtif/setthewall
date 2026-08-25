namespace :pipeline do
  desc "Test reasoned web search standalone. Usage: rake pipeline:test_search query='mid century modern wall art demand'"
  task :test_search, [:query] => :environment do |_t, args|
    query = args[:query]
    abort "Usage: rake pipeline:test_search query='your question'" if query.blank?

    require "ruby_llm/schema"

    schema = Class.new(RubyLLM::Schema) do
      string :summary, description: "Answer to the question, grounded in what was found"
      array :sources, description: "Every source actually used" do
        object do
          string :title
          string :url
        end
      end
    end

    puts "Server-side search available: #{Pipeline::SearchCapability.server_side_web_search_available?}"
    puts "Running reasoned search..."

    result = Search::ReasonedRunner.call(
      model: Pipeline::TEXT_MODEL,
      schema: schema,
      task: "Answer the user's question using live web search. Cite every source you use.",
      question: query
    )

    puts "\nSearches performed: #{result[:search_calls_made]}"
    puts "\n#{JSON.pretty_generate(result[:content])}"
  rescue Search::NoSearchPerformedError => e
    abort "FAILED: #{e.message}"
  end
end
