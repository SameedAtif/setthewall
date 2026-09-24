module Steps
  StepResult = Struct.new(:status, :data, :message, keyword_init: true) do
    def ok?             = status == :ok
    def awaiting_human? = status == :awaiting_human
    def failed?         = status == :failed
  end

  class Base
    class << self
      # Every subclass declares these. Values must match config/step_registry.yml.
      attr_reader :step_id, :mechanism, :ownership

      def step(id:, mechanism:, ownership:)
        @step_id   = id
        @mechanism = mechanism
        @ownership = ownership
      end
    end

    attr_reader :piece, :context

    def initialize(piece:, context: {})
      @piece   = piece
      @context = context
    end

    def self.call(...) = new(...).call

    def call
      Workflow::StepLogging.log("Running #{self.class.name.demodulize}")
      result = perform
      Workflow::StepLogging.log("Step result: #{result.status}")
      piece&.log_step!(
        step_id: self.class.step_id,
        mechanism: self.class.mechanism,
        outcome: result.status,
        detail: result.data || {}
      )
      result
    rescue StandardError => e
      Workflow::StepLogging.log("#{e.class}: #{e.message}", level: :error)
      piece&.update(status: "failed", last_error: "#{self.class.step_id}: #{e.message}")
      raise
    end

    private

    # Subclasses implement this and return a StepResult.
    def perform = raise NotImplementedError

    # Run a RubyLLM call through the no-progress watchdog and normalize the response to a Hash.
    # A plain blocking `ask` on a thinking model can hang with no data and no timeout; streaming
    # keeps it alive and lets the watchdog abort/retry a stall. Qwen's compatible endpoint can
    # return a schema'd response as an unparsed string when streamed, so normalize it.
    def streamed_json(chat, prompt, with: nil)
      Pipeline::Json.normalize(Pipeline::Streaming.ask(apply_thinking_budget(chat), prompt, with: with).content)
    end

    # Bound a Qwen reasoning model's thinking (kept enabled) so it can't reason unboundedly. A no-op
    # for providers/fakes that don't accept extra params.
    def apply_thinking_budget(chat)
      budget = Pipeline::QWEN_THINKING_BUDGET.to_i
      return chat unless budget.positive? && chat.respond_to?(:with_params)

      chat.with_params(enable_thinking: true, thinking_budget: budget)
    end

    def ok(data = {}, message: nil)  = StepResult.new(status: :ok, data:, message:)
    def needs_human(reason, data = {}) = StepResult.new(status: :awaiting_human, data:, message: reason)
    def fail_step(reason, data = {})   = StepResult.new(status: :failed, data:, message: reason)

    def rules(name) = KnowledgeBase::RuleSet.load(name)

    def prompt(name, **vars)
      template = Pipeline::KB_ROOT.join("prompts", "#{name}.md").read
      format(template, **vars)
    end

    # Vision models often cannot fetch remote URLs (Pinterest, blogs, etc.) server-side, so
    # download reference images locally and hand the vision call a local path instead.
    def localize_images(urls)
      Array(urls).filter_map do |url|
        url = url.to_s
        next url if url.blank? || File.exist?(url)

        ext = File.extname(URI.parse(url).path).presence || ".jpg"
        dst = Rails.root.join("tmp", "reference_images", "#{Digest::SHA256.hexdigest(url)}#{ext}")
        unless dst.exist?
          dst.dirname.mkpath
          response = Faraday.get(url) { |req| req.headers["User-Agent"] = "Mozilla/5.0" }
          next url unless response.success?

          dst.binwrite(response.body)
        end
        dst.to_s
      rescue StandardError
        url
      end
    end

    def spec  = piece.style_spec
    def scene = piece.scene_spec
  end
end
