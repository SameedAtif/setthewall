module Search
  class ReasonedRunner
    DEFAULT_MAX_ROUNDS = 6

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
    def initialize(model:, schema:, task:, question:, max_rounds: DEFAULT_MAX_ROUNDS, min_rounds: nil,
                   on_progress: nil)
      @model       = model
      @schema      = schema
      @task        = task
      @question    = question
      @max_rounds  = max_rounds
      @min_rounds  = min_rounds
      @on_progress = on_progress || ->(_message) { }
    end

    # Runs in two phases:
    #   1. research — a chat with the search tool (no schema) gathers evidence and writes a
    #      thorough, cited research report. Qwen's compatible-mode endpoint ignores
    #      `response_format` (structured output) whenever tools are present, so the schema
    #      cannot be enforced on a tool-using chat.
    #   2. extraction — a separate, tool-free chat asks for the structured answer. Structured
    #      output is still not guaranteed here (Qwen honors `response_format` inconsistently),
    #      so the extraction prompt inlines the schema and normalize_content parses whatever
    #      shape the model returns.
    def call
      start_index = (Thread.current[:web_search_trace] || []).size

      emit_progress("researching (live web search, up to #{@max_rounds} searches)")
      research_chat     = build_research_chat
      research_response = research_chat.ask(@question)
      tool_calls        = count_tool_calls(research_chat)

      if tool_calls.zero?
        raise NoSearchPerformedError,
              "Model answered without calling the search tool. Refusing to accept an " \
              "unsearched answer — this defeats the purpose of the step. Retry, or check " \
              "TAVILY_API_KEY is set."
      end

      emit_progress("extracting structured results")
      { content: extract_structured(research_response.content), search_calls_made: tool_calls,
        min_rounds_met: @min_rounds ? tool_calls >= @min_rounds : nil,
        transcript: research_chat.messages,
        searches: (Thread.current[:web_search_trace] || [])[start_index..] || [] }
    end

    private

    def emit_progress(message)
      Rails.logger.info("[ReasonedRunner] #{message}")
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
      response = RubyLLM.chat(model: @model)
                         .with_schema(@schema)
                         .ask(extraction_prompt(evidence))

      Pipeline::Json.normalize(response.content)
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
      # under-reports the real search count — the A1 gate saying "3 searches" while the log showed
      # 8 was exactly this.
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
