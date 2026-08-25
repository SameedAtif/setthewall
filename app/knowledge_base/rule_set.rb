module KnowledgeBase
  class RuleNotFoundError < StandardError; end
  class MissingCitationError < StandardError; end

  class RuleSet
    attr_reader :name, :meta, :rules

    def self.load(name)
      @cache ||= {}
      @cache[name] ||= begin
        path = Pipeline::KB_ROOT.join("rules", "#{name}.yml")
        raise RuleNotFoundError, "No rule file at #{path}" unless path.exist?

        raw = YAML.safe_load_file(path, permitted_classes: [Date])
        new(name, raw)
      end
    end

    def self.reset_cache! = @cache = nil

    def initialize(name, raw)
      @name  = name
      @meta  = raw.fetch("meta", {})
      @rules = raw.fetch("rules", {})

      if @meta["citation"].blank? || @meta["source"].blank?
        raise MissingCitationError,
              "Rule file '#{name}' is missing meta.source or meta.citation. " \
              "Every rule must carry provenance."
      end
    end

    # Nested lookup with a clear error rather than a silent nil.
    #   RuleSet.load("frame_material").fetch("minimalist_modern", "calm_ordered")
    def fetch(*keys)
      keys.map(&:to_s).reduce(rules) do |node, key|
        unless node.is_a?(Hash) && node.key?(key)
          raise RuleNotFoundError, "#{name}: no rule at path #{keys.inspect} (failed at '#{key}')"
        end
        node[key]
      end
    end

    def live? = meta["volatility"].to_s == "live"
  end
end
