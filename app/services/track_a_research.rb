module TrackAResearch
  module_function

  def latest_gate
    HumanGate.where(step_id: "A0").order(:id).last
  end

  def content
    gate = latest_gate
    return {} unless gate

    JSON.parse(gate.agent_proposal || "{}").dig("findings") || {}
  rescue JSON::ParserError
    {}
  end

  def demand_terms
    c = content
    terms = []
    terms << c["single_recommended_focus"] if c["single_recommended_focus"].present?
    Array(c["findings"]).each { |f| terms << f["theme"] if f["theme"].present? }
    terms.compact.map(&:to_s).reject(&:blank?).uniq
  end

  def demand_terms_text
    demand_terms.any? ? demand_terms.join(", ") : "None recorded."
  end

  def trend_evidence
    c = content
    lines = []
    Array(c["findings"]).each do |f|
      status = f["cross_check_confirmed"] ? "confirmed" : "not confirmed"
      lines << "- #{f['theme']}: cross-check #{status} via #{f['cross_check_platform']}"
    end
    Array(c["cross_check_attempts"]).each { |a| lines << "- #{a}" }
    lines.any? ? lines.join("\n") : "None recorded."
  end
end
