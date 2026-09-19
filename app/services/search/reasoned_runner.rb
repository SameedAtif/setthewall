module Search
  class ReasonedRunner
    DEFAULT_MAX_ROUNDS = 6
    DEFAULT_CONCURRENCY = 4
    DEFAULT_SEARCH_TIMEOUT = 20.0

    def self.call(...) = new(...).call

    # model:        which LLM to use
    # schema:       a RubyLLM::Schema class the final answer must conform to
    # task:         task-specific instructions (e.g. the A0 research brief)
    # question:     the actual user-turn content sent to the model
    # max_rounds:   search budget, to bound cost
    # min_rounds:   optional search floor — min_rounds_met in the result reports whether it was
    #               reached, so a QA layer can reject a run that stopped short without reading prose.
    # on_progress:  optional callback invoked with a short message at each checkpoint, so a
    #               long-running job can surface progress (UI) without polling the terminal.
    # scripted:     optional list of { query:, include_images:, include_domains: } — queries that
    #               are already specified by the caller. They are executed in parallel in code (not
    #               composed by the model), with their results injected into the evidence.
    def initialize(model:, schema:, task:, question:, max_rounds: DEFAULT_MAX_ROUNDS, min_rounds: nil,
                   on_progress: nil, scripted: [], stream: false)
      @model       = model
      @schema      = schema
      @task        = task
      @question    = question
      @max_rounds  = max_rounds
      @min_rounds  = min_rounds
      @on_progress = on_progress || ->(_message) { }
      @scripted    = Array(scripted)
      @stream      = stream
    end

    # Runs in two phases:
    #   1. research — scripted queries execute in parallel in code first, then a chat with the
    #      search tool (no schema) gathers the remaining evidence and writes a thorough, cited
    #      research report. The model's own searches are adaptive turns and stay sequential.
    #   2. extraction — a separate, tool-free chat asks for the structured answer.
    def call
      previous_trace = Thread.current[:web_search_trace]
      @collector = Search::Collector.new
      Thread.current[:web_search_trace] = @collector

      emit_progress("researching (live web search, up to #{@max_rounds} searches)")
      scripted_results = run_scripted_queries
      research_chat     = build_research_chat
      research_response = ask(research_chat, research_question(scripted_results))
      tool_calls        = count_tool_calls(research_chat)
      successes         = scripted_results.count { |r| r[:ok] }
      total_calls       = tool_calls + scripted_results.size

      if total_calls.zero?
        raise NoSearchPerformedError,
              "No search was performed. Refusing to accept an " \
              "unsearched answer — this defeats the purpose of the step. Retry, or check " \
              "TAVILY_API_KEY is set."
      end

      if tool_calls.zero? && successes.zero?
        raise NoSearchPerformedError,
              "All #{scripted_results.size} scripted search(es) failed or timed out — refusing to " \
              "answer without live evidence. Check connectivity and retry."
      end

      Workflow::StepLogging.log("Search calls made: #{total_calls}")
      log_scripted_summary(scripted_results)
      emit_progress("extracting structured results")
      { content: extract_structured(research_response.content), search_calls_made: total_calls,
        min_rounds_met: @min_rounds ? total_calls >= @min_rounds : nil,
        transcript: research_chat.messages,
        searches: @collector.to_a }
    ensure
      Thread.current[:web_search_trace] = previous_trace
    end

    private

    # Runs the caller-supplied queries concurrently through a bounded pool. Each task bounds itself
    # with a wall-clock timeout and never raises: a stuck or failing search becomes data so the rest
    # of the step can proceed. Results come back in the original query order for deterministic
    # evidence injection.
    def run_scripted_queries
      specs = @scripted.select { |spec| spec.present? && spec[:query].present? }
      return [] if specs.empty?

      Workflow::StepLogging.log("running #{specs.size} scripted search(es) " \
                                "(concurrency #{search_concurrency})")
      sink = Workflow::StepLogging.current
      collector = @collector
      pool = Concurrent::FixedThreadPool.new(search_concurrency)

      futures = specs.each_with_index.map do |spec, index|
        Concurrent::Future.execute(executor: pool) do
          Workflow::StepLogging.with_logger(sink) do
            Thread.current[:web_search_trace] = collector
            run_one_scripted_query(spec, index)
          end
        end
      end

      results = futures.each_with_index.map do |future, index|
        future.value(search_timeout + 5) ||
          timeout_result(specs[index][:query], index, "abandoned: no response from worker")
      end

      pool.shutdown
      pool.wait_for_termination(search_timeout)
      results.sort_by { |result| result[:index] }
    end

    def run_one_scripted_query(spec, index)
      query = spec[:query]
      Workflow::StepLogging.log("search started: #{query}")
      started = monotonic

      result = Timeout.timeout(search_timeout) do
        Tools::WebSearch.new.execute(
          query: query,
          include_images: spec.fetch(:include_images, false),
          include_domains: Array(spec[:include_domains]),
          exclude_domains: Array(spec[:exclude_domains])
        )
      end
      elapsed = elapsed_ms(started)

      if result[:error]
        Workflow::StepLogging.log("search failed: #{query} — #{result[:error]}", level: :warn)
      else
        Workflow::StepLogging.log("search done: #{query} → #{Array(result[:results]).size} results, " \
                                  "#{Array(result[:images]).size} images")
      end

      { index: index, query: query, ok: result[:error].blank?, error: result[:error],
        result: result, elapsed_ms: elapsed }
    rescue Timeout::Error
      timeout_result(query, index, "timed out after #{search_timeout}s", started: started)
    rescue StandardError => e
      elapsed = elapsed_ms(started)
      message = "#{e.class}: #{e.message}"
      Workflow::StepLogging.log("search failed: #{query} — #{message}", level: :error)
      @collector.record(query: query, result_urls: [], results: [], image_urls: [],
                        error: message, elapsed_ms: elapsed)
      { index: index, query: query, ok: false, error: message, elapsed_ms: elapsed,
        result: { error: message, query: query } }
    end

    def timeout_result(query, index, message, started: nil)
      elapsed = started ? elapsed_ms(started) : 0
      Workflow::StepLogging.log("search #{message}: #{query}", level: :warn)
      @collector.record(query: query, result_urls: [], results: [], image_urls: [],
                        error: message, elapsed_ms: elapsed)
      { index: index, query: query, ok: false, error: message, elapsed_ms: elapsed,
        result: { error: message, query: query } }
    end

    def log_scripted_summary(results)
      return if results.empty?

      ok = results.count { |result| result[:ok] }
      Workflow::StepLogging.log("searches complete: #{ok} ok, #{results.size - ok} failed")
    end

    def search_concurrency = ENV.fetch("SEARCH_CONCURRENCY", DEFAULT_CONCURRENCY).to_i.clamp(1, 8)
    def search_timeout = ENV.fetch("SEARCH_TIMEOUT_SECONDS", DEFAULT_SEARCH_TIMEOUT).to_f
    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    def elapsed_ms(started) = ((monotonic - started) * 1000).round

    def research_question(scripted_results)
      return @question if scripted_results.empty?

      successes = scripted_results.select { |result| result[:ok] }
      failures  = scripted_results.reject { |result| result[:ok] }
      parts = [@question]

      if successes.any?
        evidence = successes.map do |r|
          "Query (already executed): #{r[:query]}\n#{r[:result].to_json}"
        end.join("\n\n")
        parts << "These queries were already executed and their results are provided below. " \
                 "Use them; do not re-run them.\n\n#{evidence}"
      end

      if failures.any?
        failed = failures.map { |r| "#{r[:query]} (#{r[:error]})" }.join("; ")
        parts << "These queries were attempted but returned no evidence — do not invent their " \
                 "results: #{failed}."
      end

      parts.join("\n\n")
    end

    def emit_progress(message)
      Rails.logger.info("[ReasonedRunner] #{message}")
      Workflow::StepLogging.log(message)
      @on_progress.call(message)
    end

    def build_research_chat
      chat = RubyLLM.chat(model: @model)

      if Pipeline::SearchCapability.server_side_web_search_available?
        chat.with_server_tools(:web_search)
      else
        chat.with_tool(Tools::WebSearch.new)
      end

      chat.with_instructions(reasoning_instructions)
    end

    def extract_structured(evidence)
      chat = RubyLLM.chat(model: @model).with_schema(@schema)
      Pipeline::Json.normalize(ask(chat, extraction_prompt(evidence)).content)
    end

    # When streaming is enabled, run the call through the no-progress watchdog (stalled streams
    # abort + retry; progressing generations of any length are unaffected). The final message is
    # returned exactly as in the non-streaming path.
    def ask(chat, prompt)
      return chat.ask(prompt) unless @stream

      Pipeline::Streaming.ask(chat, prompt)
    end

    def extraction_prompt(evidence)
      <<~PROMPT
        #{@task}

        Below is the evidence gathered from live web search. Answer the question using ONLY this
        evidence — do not add facts from memory or training data.

        <evidence>
        #{evidence}
        </evidence>

        Question: #{@question}

        Respond with a SINGLE valid JSON object and nothing else — no markdown code fences, no
        prose before or after the JSON. The object must conform to this JSON schema:

        #{schema_description}
      PROMPT
    end

    def schema_description
      schema = @schema.new.to_json_schema.fetch(:schema, {}).dup
      schema.delete(:strict)
      JSON.pretty_generate(schema)
    end

    def reasoning_instructions
      <<~INSTR
        #{@task}

        Search methodology — follow this regardless of the task above:
        - Break the question into multiple distinct, focused search queries. Do not rely on
          one broad query.
        - Cross-check any important finding against at least one independent source before
          treating it as established — do not accept a single source's claim as settled.
        - If the task above specifies a numbered methodology or names required checks, you
          MUST attempt every one of them explicitly. "I already have enough evidence" is not
          a reason to skip a check the task specifically required — completeness of the
          required steps comes before efficiency. If a specific required check proves
          genuinely inaccessible (e.g. a data source that doesn't return to search tools),
          try at least one alternate route to satisfy the same requirement before giving up
          on it, and report what you tried and why it failed. Do not silently substitute a
          weaker check and present the requirement as satisfied.
        - You have a budget of up to #{@max_rounds} searches. Once every required check has
          been genuinely attempted, stop rather than padding with redundant searches — but do
          not stop early by treating "enough evidence for some checks" as "done with all of
          them."
        - If sources disagree, say so explicitly in your answer rather than silently picking
          one.
        - Every substantive claim in your final answer must trace back to something you
          actually found via search. Do not fill gaps from memory or training data — if you
          cannot find something via search, say you could not find it rather than guessing.
        - Your final answer must be a thorough, self-contained research report. Cite the source
          behind each substantive claim, because a separate step will extract a structured
          summary from this report alone and has no other access to the search results.
      INSTR
    end

    def count_tool_calls(chat)
      # Count individual tool invocations, not tool-call messages. The model can batch several
      # searches into one assistant message (parallel tool calls), and counting messages then
      # under-reports the real search count.
      chat.messages.sum do |m|
        next 0 unless m.respond_to?(:tool_call?) && m.tool_call?

        if m.respond_to?(:tool_calls) && m.tool_calls.respond_to?(:size)
          m.tool_calls.size
        else
          1
        end
      end
    rescue StandardError
      # If message introspection isn't available in the installed version, this can't verify
      # search actually happened — fail safe rather than assume success.
      0
    end
  end
end
