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
