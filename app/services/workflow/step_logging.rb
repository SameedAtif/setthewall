module Workflow
  # Per-thread sink for the log of the cell currently executing. CellRunner wraps a step's
  # execution with `with_logger`, so step classes, QA agents and tools can emit progress lines
  # without being handed a logger explicitly. Outside a notebook cell (e.g. the Conductor) this
  # is a no-op.
  module StepLogging
    KEY = :setthewall_step_logger

    module_function

    def with_logger(callable)
      previous = Thread.current[KEY]
      Thread.current[KEY] = callable
      yield
    ensure
      Thread.current[KEY] = previous
    end

    def log(message, level: :info)
      Thread.current[KEY]&.call(message, level: level)
    end

    # The sink installed on the current thread, if any. Captured by parallel search workers so they
    # can re-install it (thread-locals are not inherited by pool threads).
    def current = Thread.current[KEY]
  end
end
