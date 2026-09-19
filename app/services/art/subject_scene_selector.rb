module Art
  # Picks one (subject, scene-pattern) pair per batch item in application code, before the
  # synthesis LLM call is made. The synthesis call must see exactly one subject and one pattern —
  # never the full list — because an LLM shown a list blends them into one overloaded,
  # everything-emphasized-equally image.
  class SubjectSceneSelector
    def self.pairs(spec, n)
      new(spec, n).pairs
    end

    def initialize(spec, n)
      subjects = Array(spec.subject_research["recurring_subjects"])
      # A style may curate which of the researched subjects are reference-consistent; when present,
      # only those are selectable (so an off-vibe subject can never drive a candidate).
      curated = Array(spec.subject_research["curated_subjects"]).map(&:to_s).reject(&:blank?)
      subjects = subjects.select { |s| curated.include?(s["subject"].to_s) } if curated.any?
      @subjects = subjects
      @patterns = Array(spec.scene_research["scene_patterns"])
      @n = n
    end

    # Draws (subject, pattern) combinations without replacement, then repeats with a shifted
    # offset once exhausted — so a batch explores real, evidence-backed variation.
    def pairs
      return Array.new(@n) { { subject: nil, pattern: nil } } if @subjects.empty? || @patterns.empty?

      combos = @subjects.product(@patterns)
      Array.new(@n) do |i|
        subject, pattern = combos[i % combos.size]
        { subject: subject, pattern: pattern }
      end
    end
  end
end
