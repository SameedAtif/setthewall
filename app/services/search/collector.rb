module Search
  # Thread-safe collection of live-search traces for a single ReasonedRunner call. It is assigned to
  # Thread.current[:web_search_trace] in the parent thread and re-assigned in each parallel search
  # worker, so Tools::WebSearch#trace keeps appending here without knowing about concurrency.
  class Collector
    def initialize
      @entries = Concurrent::Array.new
    end

    def <<(entry)
      @entries << entry
      self
    end

    def record(entry) = self << entry

    def to_a = @entries.to_a
    def size = @entries.size
    def empty? = @entries.empty?
  end
end
