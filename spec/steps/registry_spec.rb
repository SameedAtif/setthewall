require "rails_helper"

RSpec.describe "step registry" do
  def registry
    raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
    [
      *(raw.dig("phase_1", "track_a", "steps") || []),
      *(raw.dig("phase_1", "track_b", "steps") || []),
      *(raw.dig("phase_1", "track_c", "steps") || []),
      *(raw.dig("phase_2", "steps") || []),
      *(raw.dig("phase_3_module_1", "steps") || [])
    ]
  end

  it "holds exactly 41 steps" do
    expect(registry.size).to eq(41)
  end

  it "has every entry resolve to a class with matching step_id + ownership" do
    registry.each do |s|
      klass = s["klass"].safe_constantize
      expect(klass).not_to be_nil, "step #{s['id']} class #{s['klass']} does not resolve"
      expect(klass.step_id).to eq(s["id"])
      expect(klass.ownership).to eq(s["ownership"])
    end
  end

  it "has 18 human-gated steps" do
    expect(registry.count { |s| s["human_gate"] }).to eq(18)
  end

  it "has no duplicate step ids" do
    ids = registry.map { |s| s["id"] }
    expect(ids.uniq.size).to eq(ids.size)
  end

  it "has phase counts of 19 / 13 / 9" do
    raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
    expect(raw["phase_1"].values.sum { |t| t["steps"].size }).to eq(19)
    expect(raw["phase_2"]["steps"].size).to eq(13)
    expect(raw["phase_3_module_1"]["steps"].size).to eq(9)
  end
end
