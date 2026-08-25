require "test_helper"

class RuleSetTest < ActiveSupport::TestCase
  test "raises MissingCitationError for an uncited rule file" do
    name = "test_uncited_#{SecureRandom.hex(4)}"
    path = Pipeline::KB_ROOT.join("rules", "#{name}.yml")
    path.write("meta:\n  source: x\nrules: {}\n")
    track_kb_file(path)
    KnowledgeBase::RuleSet.reset_cache!

    assert_raises(KnowledgeBase::MissingCitationError) do
      KnowledgeBase::RuleSet.load(name)
    end
  ensure
    KnowledgeBase::RuleSet.reset_cache!
  end

  test "raises RuleNotFoundError for a missing rule file" do
    assert_raises(KnowledgeBase::RuleNotFoundError) do
      KnowledgeBase::RuleSet.load("definitely-not-a-rule-#{SecureRandom.hex(4)}")
    end
  end

  test "fetch returns a nested value" do
    r = KnowledgeBase::RuleSet.load("frame_material")
    assert_equal "gold", r.fetch("metal_finish", "calm_warm", "finish")
  end

  test "fetch raises on a missing path rather than returning nil" do
    r = KnowledgeBase::RuleSet.load("frame_material")
    assert_raises(KnowledgeBase::RuleNotFoundError) { r.fetch("nope", "nope") }
  end

  test "live? reflects the volatility flag" do
    assert KnowledgeBase::RuleSet.load("etsy_tags").live?
    refute KnowledgeBase::RuleSet.load("frame_material").live?
  end
end
