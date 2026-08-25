# Module 00b — Reasoned Web Search Capability

> **Self-contained addendum to module 00.** This exists because Track A's A0 and A1 steps require
> real, live, multi-source web search — not a single query, and never an answer from the model's
> training data. Do not search the internet for how to build this; it is fully specified below.

---

## Contract

**Depends on:** module 00 (`Pipeline` initializer, `.env` conventions, Faraday already in the
Gemfile).

**Provides:**
- `Tools::WebSearch` — a client-side `RubyLLM::Tool` that calls a real search API. Works regardless
  of which RubyLLM version is installed.
- `Pipeline::SearchCapability` — runtime detection of whether the installed RubyLLM/provider also
  offers server-side web search, so it can be preferred when available without hard-depending on it.
- `Search::ReasonedRunner` — the multi-turn orchestration service. This is what "reasoned search"
  means in this project: the model decomposes a question into multiple distinct queries, cross-checks
  findings across independent sources, and is mechanically prevented from answering without having
  actually searched.
- `lib/tasks/search.rake` — a rake task to test the capability standalone, outside the pipeline.

**Consumed by:** module 01 (A0, A1) directly. Available to any future step that needs live search.

**Amends, does not redefine, module 00:** this module adds keys to the `.env` file module 00 created
and adds `gem "tavily-ruby"` alternative note — it does not recreate `.env` or the Gemfile from
scratch. If module 00 has already been built, just add the lines below to the existing files.

---

## 1. Why a custom tool, not a guessed native one

An earlier draft of this plan assumed `RubyLLM::Tools::WebSearch` — a built-in tool — would exist.
That was a guess, not a verified fact, and it turned out to be wrong: RubyLLM has no such constant.
What actually exists, as of current research:

- RubyLLM supports **custom client-side tools** via subclassing `RubyLLM::Tool` — this has been
  stable across RubyLLM versions and is the documented, reliable mechanism.
- Some RubyLLM versions additionally expose **provider-hosted server-side tools** (Anthropic's own
  web search, run on Anthropic's infrastructure) via `with_server_tools`. Support for this has been
  reported as inconsistent across recent versions — present in some release notes, reported missing
  in a review of a nearby version. **Do not hard-code a dependency on this.**

The fix: build the reliable path (a real custom tool calling a real search API) as the primary
mechanism, and *opportunistically* use the server-side path if the installed gem version supports it,
detected at runtime rather than assumed.

---

## 2. `Tools::WebSearch` — the real search tool

Uses [Tavily](https://tavily.com), a search API built specifically for LLM/agent use — it returns
clean title/URL/content-snippet results rather than raw HTML, which is what a tool result needs.

### 2.1 Add to `.env` (appends to the file module 00 created)

```bash
# .env — add these lines
TAVILY_API_KEY=
```

```bash
# .env.example — add these lines
TAVILY_API_KEY=
```

Get a key at tavily.com — it has a free tier sufficient for this pipeline's volume (A0/A1 run
per-style, infrequently, not per-piece).

### 2.2 The tool class

```ruby
# app/tools/web_search.rb
module Tools
  class WebSearch < RubyLLM::Tool
    description <<~DESC
      Search the live web. Returns titles, URLs, and content snippets from real,
      independently-sourced pages. Use this whenever you need current information, cannot
      answer reliably from training data, or need to attribute a claim to a real, checkable
      source. Issue multiple distinct, focused queries rather than one broad query when you
      need to cross-check a finding across independent sources.
    DESC

    param :query, type: :string,
          desc: "A focused search query, 2-6 words works best."
    param :max_results, type: :integer, required: false,
          desc: "Number of results to return. Default 5, max 10."

    def execute(query:, max_results: 5)
      max_results = max_results.to_i.clamp(1, 10)

      response = connection.post("search") do |req|
        req.body = {
          api_key: ENV.fetch("TAVILY_API_KEY"),
          query: query,
          max_results: max_results,
          include_answer: false,
          search_depth: "basic"
        }
      end

      unless response.success?
        return { error: "search request failed (HTTP #{response.status})", query: query }
      end

      results = JSON.parse(response.body)["results"] || []
      if results.empty?
        return { error: "no results found", query: query }
      end

      results.map do |r|
        {
          title: r["title"],
          url: r["url"],
          snippet: r["content"].to_s.truncate(500)
        }
      end
    rescue Faraday::Error, JSON::ParserError => e
      { error: "search tool error: #{e.message}", query: query }
    end

    private

    def connection
      @connection ||= Faraday.new(url: "https://api.tavily.com/") do |f|
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
```

**Failure is visible, not silent.** A failed search returns `{error: ..., query: ...}` as the tool
result — the model sees the failure and can retry with a different query or report it, rather than
the tool raising and killing the whole chat turn.

---

## 3. `Pipeline::SearchCapability` — runtime detection

```ruby
# app/services/pipeline/search_capability.rb
module Pipeline
  module SearchCapability
    # True only if the installed RubyLLM actually exposes with_server_tools on Chat.
    # Checked at runtime, not assumed from documentation, since this has been reported as
    # inconsistent across recent RubyLLM versions.
    def self.server_side_web_search_available?
      RubyLLM::Chat.instance_methods.include?(:with_server_tools)
    rescue NameError, StandardError
      false
    end
  end
end
```

---

## 4. `Search::ReasonedRunner` — the reasoning + search orchestrator

This is the piece that actually implements "reasoned search": it forces multi-query decomposition,
cross-checking, and — critically — **refuses to accept an answer where the model never actually
called the search tool.**

```ruby
# app/services/search/reasoned_runner.rb
module Search
  class NoSearchPerformedError < StandardError; end

  class ReasonedRunner
    DEFAULT_MAX_ROUNDS = 6

    def self.call(...) = new(...).call

    # model:        which LLM to use
    # schema:       a RubyLLM::Schema class the final answer must conform to
    # task:         task-specific instructions (e.g. the A0 research brief)
    # question:     the actual user-turn content sent to the model
    # max_rounds:   search budget, to bound cost
    def initialize(model:, schema:, task:, question:, max_rounds: DEFAULT_MAX_ROUNDS)
      @model      = model
      @schema     = schema
      @task       = task
      @question   = question
      @max_rounds = max_rounds
    end

    def call
      chat = build_chat

      response   = chat.ask(@question)
      tool_calls = count_tool_calls(chat)

      if tool_calls.zero?
        raise NoSearchPerformedError,
              "Model answered without calling the search tool. Refusing to accept an " \
              "unsearched answer — this defeats the purpose of the step. Retry, or check " \
              "TAVILY_API_KEY is set."
      end

      { content: response.content, search_calls_made: tool_calls, transcript: chat.messages }
    end

    private

    def build_chat
      chat = RubyLLM.chat(model: @model).with_schema(@schema)

      chat = if Pipeline::SearchCapability.server_side_web_search_available?
               chat.with_server_tools(:web_search)
             else
               chat.with_tool(Tools::WebSearch.new)
             end

      # NOTE: verify the exact instructions-setting method against the installed RubyLLM
      # version before relying on this — `with_instructions` is documented in RubyLLM's Rails
      # integration guide ("System Instructions" section) but confirm the method name matches
      # what's installed:
      #   bundle show ruby_llm  # then grep the Chat class for the setter
      chat.with_instructions(reasoning_instructions)
    end

    def reasoning_instructions
      <<~INSTR
        #{@task}

        Search methodology — follow this regardless of the task above:
        - Break the question into multiple distinct, focused search queries. Do not rely on
          one broad query.
        - Cross-check any important finding against at least one independent source before
          treating it as established — do not accept a single source's claim as settled.
        - You have a budget of up to #{@max_rounds} searches. Stop once you have enough
          independently-confirmed evidence to answer — do not pad with redundant searches.
        - If sources disagree, say so explicitly in your answer rather than silently picking
          one.
        - Every substantive claim in your final answer must trace back to something you
          actually found via search. Do not fill gaps from memory or training data — if you
          cannot find something via search, say you could not find it rather than guessing.
      INSTR
    end

    def count_tool_calls(chat)
      chat.messages.count do |m|
        m.respond_to?(:tool_call?) ? m.tool_call? : (m.respond_to?(:role) && m.role == :tool)
      end
    rescue StandardError
      # If message introspection isn't available in the installed version, this can't verify
      # search actually happened — fail safe rather than assume success.
      0
    end
  end
end
```

**Why raise on zero tool calls rather than just logging a warning:** this is the single most
important guard in this module. Module 01's whole point for A0/A1 is that findings must come from
real search, not the model's memory. A model that answers confidently without searching produces
output indistinguishable from grounded output unless something checks for it. This check is that
something.

---

## 5. Rake task — standalone testing

```ruby
# lib/tasks/search.rake
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
```

---

## 6. Verification for this module

```bash
# 1. Tool executes and returns real results (requires TAVILY_API_KEY set)
bin/rails runner '
  r = Tools::WebSearch.new.execute(query: "japandi wall art style guide")
  puts r.first.is_a?(Hash) ? "ok: #{r.size} results, first title=#{r.first[:title]}" : r.inspect
'

# 2. Capability detection runs without raising even if the method is absent
bin/rails runner 'puts Pipeline::SearchCapability.server_side_web_search_available?'

# 3. ReasonedRunner refuses an unsearched answer — force this by stubbing
#    (run in `rails console`, not runner, so the stub holds for the call)
bin/rails console
> require "ostruct"
> fake_chat = Object.new
> def fake_chat.with_schema(*); self; end
> def fake_chat.with_tool(*); self; end
> def fake_chat.with_instructions(*); self; end
> def fake_chat.ask(*); OpenStruct.new(content: {"summary" => "no search happened"}); end
> def fake_chat.messages; []; end
> RubyLLM.define_singleton_method(:chat) { |*| fake_chat }
> begin
>   Search::ReasonedRunner.call(model: "x", schema: Class.new(RubyLLM::Schema), task: "t", question: "q")
>   puts "FAIL — should have raised"
> rescue Search::NoSearchPerformedError
>   puts "correctly refused an unsearched answer"
> end

# 4. Rake task runs end to end
bin/rails pipeline:test_search query='boho wall art demand'
```

**Also verify by hand:** confirm the exact RubyLLM method name for setting system instructions
against the actually-installed gem version (`bundle show ruby_llm`, then check the `Chat` class) —
the plan uses `with_instructions` based on the gem's documented Rails integration guide, but this is
exactly the kind of detail that can drift between versions and should be confirmed against what's
actually installed before shipping.

---

## 7. How this changes module 01

A0 and A1 in `01-phase1-track-a-style-axes.md` are updated to call `Search::ReasonedRunner` instead
of the placeholder `.with_tool(RubyLLM::Tools::WebSearch)` line — see the patch applied to that file.
The "fall back to human manual paste" hedge from the original A0 draft is removed: it's no longer
needed, because `ReasonedRunner` now mechanically guarantees search actually happened rather than
hoping a tool exists.
