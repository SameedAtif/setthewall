require "test_helper"

# Verifies the canonical 38-step registry is consistent with the implementing classes.
class RegistryTest < ActiveSupport::TestCase
  def registry
    @registry ||= begin
      raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
      [
        *(raw.dig("phase_1", "track_a", "steps") || []),
        *(raw.dig("phase_1", "track_b", "steps") || []),
        *(raw.dig("phase_1", "track_c", "steps") || []),
        *(raw.dig("phase_2", "steps") || []),
        *(raw.dig("phase_3_module_1", "steps") || [])
      ]
    end
  end

  test "registry holds exactly 38 steps" do
    assert_equal 38, registry.size
  end

  test "every registry entry resolves to a class with matching step_id + ownership" do
    registry.each do |s|
      klass = s["klass"].safe_constantize
      assert klass, "step #{s['id']} class #{s['klass']} does not resolve"
      assert_equal s["id"], klass.step_id, "step_id mismatch for #{s['id']}"
      assert_equal s["ownership"], klass.ownership, "ownership mismatch for #{s['id']}"
    end
  end

  test "17 steps are human-gated" do
    gates = registry.count { |s| s["human_gate"] }
    assert_equal 17, gates
  end

  test "no step id is duplicated" do
    ids = registry.map { |s| s["id"] }
    assert_equal ids.uniq.size, ids.size
  end

  test "phase counts are 16 / 13 / 9" do
    raw = YAML.safe_load_file(Rails.root.join("config/step_registry.yml"))
    p1 = raw["phase_1"].values.sum { |t| t["steps"].size }
    assert_equal 16, p1
    assert_equal 13, raw["phase_2"]["steps"].size
    assert_equal 9, raw["phase_3_module_1"]["steps"].size
  end
end
